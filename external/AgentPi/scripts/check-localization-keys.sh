#!/usr/bin/env bash
set -euo pipefail

ROOT="app/modules/AgentPiCore/Sources/AgentPi/Resources"
SOURCE_ROOT="app/modules/AgentPiCore/Sources/AgentPi"
BASE_LOCALE="en"
LOCALES=(en zh-Hans ko ja vi)
BASE_FILE="$ROOT/${BASE_LOCALE}.lproj/Localizable.strings"

if [[ ! -f "$BASE_FILE" ]]; then
  echo "Base localization file not found: $BASE_FILE" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

extract_keys() {
  local file="$1"
  sed -E -n 's/^"([^"]+)"[[:space:]]*=.*/\1/p' "$file" | LC_ALL=C sort -u
}

extract_keys "$BASE_FILE" > "$tmpdir/base.keys"
status=0

for locale in "${LOCALES[@]}"; do
  file="$ROOT/${locale}.lproj/Localizable.strings"

  if [[ ! -f "$file" ]]; then
    echo "Missing locale file: $file" >&2
    status=1
    continue
  fi

  extract_keys "$file" > "$tmpdir/${locale}.keys"

  missing="$tmpdir/${locale}.missing"
  extra="$tmpdir/${locale}.extra"

  comm -23 "$tmpdir/base.keys" "$tmpdir/${locale}.keys" > "$missing"
  comm -13 "$tmpdir/base.keys" "$tmpdir/${locale}.keys" > "$extra"

  if [[ -s "$missing" || -s "$extra" ]]; then
    status=1
    echo "Locale mismatch: $locale"
    if [[ -s "$missing" ]]; then
      echo "  Missing keys:"
      sed 's/^/    - /' "$missing"
    fi
    if [[ -s "$extra" ]]; then
      echo "  Extra keys:"
      sed 's/^/    - /' "$extra"
    fi
  fi
done

used_keys_file="$tmpdir/used.keys"
rg --multiline --multiline-dotall --no-filename -o -P 'L10n\.(?:t|f)\(\s*"([^"]+)"' "$SOURCE_ROOT" -g '*.swift' \
  | sed -E 's/.*L10n\.(t|f)\([[:space:]]*"([^"]+)".*/\2/' \
  | LC_ALL=C sort -u > "$used_keys_file"

missing_in_base="$tmpdir/base.missing_from_source"
comm -23 "$used_keys_file" "$tmpdir/base.keys" > "$missing_in_base"
if [[ -s "$missing_in_base" ]]; then
  status=1
  echo "Base locale is missing keys referenced in source:" >&2
  sed 's/^/  - /' "$missing_in_base" >&2
fi

if [[ "$status" -ne 0 ]]; then
  echo "Localization key check failed." >&2
  exit "$status"
fi

echo "Localization keys are consistent across: ${LOCALES[*]}"
echo "All L10n keys referenced in source exist in ${BASE_LOCALE}.lproj."
