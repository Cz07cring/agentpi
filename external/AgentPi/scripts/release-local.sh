#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") <version> [--skip-notarize]

Example:
  $(basename "$0") 1.0.4
  $(basename "$0") 1.0.4 --skip-notarize
USAGE
}

log() {
  printf '[release-local] %s\n' "$*"
}

fail() {
  printf '[release-local] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: $cmd"
  fi
}

find_sign_update() {
  if command -v sign_update >/dev/null 2>&1; then
    command -v sign_update
    return 0
  fi

  local candidate=""
  candidate="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

VERSION=""
SKIP_NOTARIZE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-notarize)
      SKIP_NOTARIZE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
      else
        fail "Unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -n "$VERSION" ]] || { usage; fail "Version is required"; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Version must be semantic (x.y.z), got '$VERSION'"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"
APPCAST_REL="external/AgentPi/appcast.xml"
APPCAST_PATH="$REPO_ROOT/$APPCAST_REL"
PBPX_PATH="$PROJECT_ROOT/app/AgentPi.xcodeproj/project.pbxproj"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_REPO="Cz07cring/agentpi"
DEFAULT_BRANCH="main"
RAW_APPCAST_URL="https://raw.githubusercontent.com/${RELEASE_REPO}/${DEFAULT_BRANCH}/external/AgentPi/appcast.xml"

SPARKLE_KEY_LIB="$SCRIPT_DIR/lib/sparkle-key.sh"
APPCAST_ITEM_GENERATOR="$SCRIPT_DIR/generate-appcast-item.sh"
APPCAST_VALIDATOR="$SCRIPT_DIR/validate-appcast.sh"
BUILD_SCRIPT="$SCRIPT_DIR/build-dmg.sh"

require_cmd git
require_cmd gh
require_cmd xcodebuild
require_cmd xcrun
require_cmd ditto
require_cmd shasum
require_cmd awk
require_cmd sed
require_cmd grep
require_cmd rg
require_cmd curl
require_cmd security

[[ -f "$SPARKLE_KEY_LIB" ]] || fail "Missing helper: $SPARKLE_KEY_LIB"
[[ -f "$APPCAST_ITEM_GENERATOR" ]] || fail "Missing helper: $APPCAST_ITEM_GENERATOR"
[[ -f "$APPCAST_VALIDATOR" ]] || fail "Missing helper: $APPCAST_VALIDATOR"
[[ -x "$BUILD_SCRIPT" ]] || fail "Build script is not executable: $BUILD_SCRIPT"

if ! gh auth status >/dev/null 2>&1; then
  fail "GitHub CLI is not authenticated. Run: gh auth login"
fi

CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  fail "Release must run from branch '$DEFAULT_BRANCH' (current: '$CURRENT_BRANCH')."
fi

MARKETING_VERSION="$(rg -n "MARKETING_VERSION = " "$PBPX_PATH" | head -1 | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/')"
[[ -n "$MARKETING_VERSION" ]] || fail "Failed to read MARKETING_VERSION from $PBPX_PATH"
[[ "$MARKETING_VERSION" == "$VERSION" ]] || fail "MARKETING_VERSION ($MARKETING_VERSION) does not match requested version ($VERSION)."

TAG="v${VERSION}"

log "Using repository root: $REPO_ROOT"
log "Version: $VERSION"
log "Tag: $TAG"

log "Building app and DMG..."
if [[ "$SKIP_NOTARIZE" == true ]]; then
  "$BUILD_SCRIPT"
else
  "$BUILD_SCRIPT" --notarize
fi

APP_PATH="$BUILD_DIR/AgentPi.app"
DMG_PATH="$BUILD_DIR/AgentPi.dmg"
[[ -d "$APP_PATH" ]] || fail "Missing app bundle after build: $APP_PATH"
[[ -f "$DMG_PATH" ]] || fail "Missing DMG after build: $DMG_PATH"
[[ -f "$DMG_PATH.sha256" ]] || fail "Missing DMG checksum: $DMG_PATH.sha256"

log "Generating Sparkle zip and checksums..."
(
  cd "$BUILD_DIR"
  rm -f AgentPi.app.zip AgentPi.app.zip.sha256 AgentPi.app.zip.size sparkle-signature.txt
  ditto -c -k --keepParent AgentPi.app AgentPi.app.zip
  stat -f%z AgentPi.app.zip > AgentPi.app.zip.size
  shasum -a 256 AgentPi.app.zip > AgentPi.app.zip.sha256
)

APP_ZIP_PATH="$BUILD_DIR/AgentPi.app.zip"
APP_ZIP_SHA_PATH="$BUILD_DIR/AgentPi.app.zip.sha256"
APP_ZIP_SIZE_PATH="$BUILD_DIR/AgentPi.app.zip.size"

[[ -f "$APP_ZIP_PATH" ]] || fail "Missing Sparkle zip: $APP_ZIP_PATH"
[[ -f "$APP_ZIP_SHA_PATH" ]] || fail "Missing Sparkle zip checksum: $APP_ZIP_SHA_PATH"
[[ -f "$APP_ZIP_SIZE_PATH" ]] || fail "Missing Sparkle zip size file: $APP_ZIP_SIZE_PATH"

if ! SIGN_UPDATE_BIN="$(find_sign_update)"; then
  fail "Sparkle sign_update binary not found. Build once in Xcode or install Sparkle toolchain."
fi

source "$SPARKLE_KEY_LIB"
SPARKLE_PRIVATE_KEY="$(read_sparkle_private_key)"

log "Signing AgentPi.app.zip with Sparkle EdDSA key..."
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE_BIN" "$APP_ZIP_PATH" --ed-key-file - > "$BUILD_DIR/sparkle-signature.txt"
[[ -s "$BUILD_DIR/sparkle-signature.txt" ]] || fail "Sparkle signature file is empty."

ED_SIGNATURE="$(grep -Eo 'edSignature="[^"]+"' "$BUILD_DIR/sparkle-signature.txt" | head -1 | sed -E 's/edSignature="([^"]+)"/\1/' || true)"
if [[ -z "$ED_SIGNATURE" ]]; then
  ED_SIGNATURE="$(tr -d '\r\n' < "$BUILD_DIR/sparkle-signature.txt")"
fi
[[ -n "$ED_SIGNATURE" ]] || fail "Failed to parse Sparkle edSignature from sparkle-signature.txt"

ZIP_LENGTH="$(tr -d '[:space:]' < "$APP_ZIP_SIZE_PATH")"
[[ "$ZIP_LENGTH" =~ ^[0-9]+$ ]] || fail "Invalid zip length: '$ZIP_LENGTH'"

if git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  log "Local tag $TAG already exists."
else
  log "Creating local tag $TAG"
  git -C "$REPO_ROOT" tag "$TAG"
fi

if git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/$TAG" | grep -q .; then
  log "Remote tag $TAG already exists."
else
  log "Pushing tag $TAG to origin"
  git -C "$REPO_ROOT" push origin "$TAG"
fi

log "Publishing release assets to GitHub ($RELEASE_REPO)..."
if gh release view "$TAG" --repo "$RELEASE_REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" \
    "$DMG_PATH" \
    "$DMG_PATH.sha256" \
    "$APP_ZIP_PATH" \
    "$APP_ZIP_SHA_PATH" \
    --repo "$RELEASE_REPO" \
    --clobber
else
  gh release create "$TAG" \
    "$DMG_PATH" \
    "$DMG_PATH.sha256" \
    "$APP_ZIP_PATH" \
    "$APP_ZIP_SHA_PATH" \
    --repo "$RELEASE_REPO" \
    --title "$TAG" \
    --generate-notes
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
NEW_ITEM_PATH="$TMP_DIR/new_item.xml"
FILTERED_APPCAST_PATH="$TMP_DIR/appcast.filtered.xml"
UPDATED_APPCAST_PATH="$TMP_DIR/appcast.updated.xml"

PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S %z")"
"$APPCAST_ITEM_GENERATOR" \
  --version "$VERSION" \
  --signature "$ED_SIGNATURE" \
  --length "$ZIP_LENGTH" \
  --repo "$RELEASE_REPO" \
  --pub-date "$PUB_DATE" \
  --min-system-version "14.0" > "$NEW_ITEM_PATH"

log "Updating appcast.xml with version $VERSION..."
awk -v version="$VERSION" '
BEGIN {
  in_item = 0
  item_has_version = 0
  item = ""
}
{
  line = $0
  if (!in_item && line ~ /^[[:space:]]*<item>[[:space:]]*$/) {
    in_item = 1
    item_has_version = 0
    item = line ORS
    next
  }

  if (in_item) {
    item = item line ORS
    if (line ~ ("<sparkle:shortVersionString>" version "</sparkle:shortVersionString>")) {
      item_has_version = 1
    }
    if (line ~ /^[[:space:]]*<\/item>[[:space:]]*$/) {
      if (!item_has_version) {
        printf "%s", item
      }
      in_item = 0
      item = ""
      item_has_version = 0
    }
    next
  }

  print line
}
END {
  if (in_item && !item_has_version) {
    printf "%s", item
  }
}
' "$APPCAST_PATH" > "$FILTERED_APPCAST_PATH"

if ! awk -v item_file="$NEW_ITEM_PATH" '
BEGIN { inserted = 0 }
/<language>en<\/language>/ {
  print
  print ""
  while ((getline line < item_file) > 0) {
    print line
  }
  close(item_file)
  inserted = 1
  next
}
{ print }
END {
  if (inserted == 0) {
    exit 2
  }
}
' "$FILTERED_APPCAST_PATH" > "$UPDATED_APPCAST_PATH"; then
  fail "Failed to insert new item into appcast.xml (missing <language>en</language> anchor?)"
fi

cp "$UPDATED_APPCAST_PATH" "$APPCAST_PATH"
"$APPCAST_VALIDATOR" "$APPCAST_PATH" "$VERSION"

git -C "$REPO_ROOT" add "$APPCAST_REL"
if git -C "$REPO_ROOT" diff --cached --quiet -- "$APPCAST_REL"; then
  log "No appcast changes to commit."
else
  git -C "$REPO_ROOT" commit -m "chore(release): update appcast for v$VERSION" -- "$APPCAST_REL"
  git -C "$REPO_ROOT" push origin "$DEFAULT_BRANCH"
fi

log "Waiting for remote appcast propagation..."
REMOTE_OK=false
for attempt in $(seq 1 12); do
  if REMOTE_APPCAST="$(curl -fsSL "$RAW_APPCAST_URL" 2>/dev/null || true)"; then
    if grep -q "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>" <<<"$REMOTE_APPCAST"; then
      REMOTE_OK=true
      break
    fi
  fi
  sleep 5
done

if [[ "$REMOTE_OK" != true ]]; then
  fail "Remote appcast did not show version $VERSION within 60 seconds: $RAW_APPCAST_URL"
fi

log "Release completed successfully."
log "Release: https://github.com/${RELEASE_REPO}/releases/tag/${TAG}"
log "Raw appcast: $RAW_APPCAST_URL"
