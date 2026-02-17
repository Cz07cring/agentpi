#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build-macos/DerivedData/Build/Products/Debug/AgentPi.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not built yet at: $APP_PATH" >&2
  echo "Run: npm run mac:build" >&2
  exit 1
fi

open "$APP_PATH"
