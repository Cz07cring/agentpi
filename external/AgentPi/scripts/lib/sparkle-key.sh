#!/bin/bash
set -euo pipefail

DEFAULT_SERVICE="Private key for signing Sparkle updates"
DEFAULT_ACCOUNT="ed25519"

read_sparkle_private_key() {
  local service="${1:-${SPARKLE_KEYCHAIN_SERVICE:-$DEFAULT_SERVICE}}"
  local account="${2:-${SPARKLE_KEYCHAIN_ACCOUNT:-$DEFAULT_ACCOUNT}}"
  local private_key

  if ! private_key="$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null)"; then
    cat >&2 <<MSG
ERROR: Sparkle private key not found in Keychain.

Expected Keychain item:
  service: $service
  account: $account

Import your Sparkle private key first, then retry.
Example:
  security add-generic-password -U -a "$account" -s "$service" -w '<SPARKLE_PRIVATE_KEY>'
MSG
    return 1
  fi

  private_key="${private_key//$'\r'/}"
  private_key="${private_key//$'\n'/}"

  if [[ -z "$private_key" ]]; then
    echo "ERROR: Sparkle private key is empty in Keychain item service='$service' account='$account'." >&2
    return 1
  fi

  printf '%s' "$private_key"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  read_sparkle_private_key "$@"
fi
