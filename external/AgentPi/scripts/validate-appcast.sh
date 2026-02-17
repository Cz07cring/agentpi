#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [appcast.xml path] [expected_version]

Examples:
  $(basename "$0")
  $(basename "$0") /path/to/appcast.xml 1.0.4
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPCAST_PATH="${1:-$PROJECT_ROOT/appcast.xml}"
EXPECTED_VERSION="${2:-}"

if [[ "$APPCAST_PATH" == "-h" || "$APPCAST_PATH" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$APPCAST_PATH" ]]; then
  echo "ERROR: appcast file not found: $APPCAST_PATH" >&2
  exit 1
fi

if command -v xmlstarlet >/dev/null 2>&1; then
  if ! xmlstarlet val -w "$APPCAST_PATH" >/dev/null 2>&1; then
    echo "ERROR: appcast.xml is not well-formed XML." >&2
    exit 1
  fi
fi

if ! grep -q '<rss ' "$APPCAST_PATH"; then
  echo "ERROR: appcast.xml is missing <rss> root." >&2
  exit 1
fi

if ! grep -q '<channel>' "$APPCAST_PATH"; then
  echo "ERROR: appcast.xml is missing <channel>." >&2
  exit 1
fi

if ! grep -q '<item>' "$APPCAST_PATH"; then
  echo "ERROR: appcast.xml has no <item> entries." >&2
  exit 1
fi

FIRST_ITEM="$(awk '
  /<item>/ {in_item=1}
  in_item {print}
  /<\/item>/ && in_item {exit}
' "$APPCAST_PATH")"

if [[ -z "$FIRST_ITEM" ]]; then
  echo "ERROR: failed to parse first <item> from appcast.xml." >&2
  exit 1
fi

for required in "<sparkle:shortVersionString>" "sparkle:edSignature=" "length=" "url=\"https://github.com/" "AgentPi.app.zip\""; do
  if ! grep -q "$required" <<<"$FIRST_ITEM"; then
    echo "ERROR: first appcast item is missing required field: $required" >&2
    exit 1
  fi
done

if [[ -n "$EXPECTED_VERSION" ]]; then
  if ! grep -q "<sparkle:shortVersionString>${EXPECTED_VERSION}</sparkle:shortVersionString>" "$APPCAST_PATH"; then
    echo "ERROR: expected version ${EXPECTED_VERSION} not found in appcast.xml." >&2
    exit 1
  fi
fi

echo "appcast validation passed: $APPCAST_PATH"
if [[ -n "$EXPECTED_VERSION" ]]; then
  echo "version check passed: $EXPECTED_VERSION"
fi
