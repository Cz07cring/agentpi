#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTPI_DIR="$ROOT_DIR/external/AgentPi"
DERIVED_DATA_DIR="$ROOT_DIR/.build-macos/DerivedData"
WORKSPACE_PATH="$AGENTPI_DIR/app/AgentPi.xcworkspace"
PROJECT_PATH="$AGENTPI_DIR/app/AgentPi.xcodeproj"

if [[ ! -d "$AGENTPI_DIR" ]]; then
  echo "AgentPi source not found at: $AGENTPI_DIR" >&2
  echo "Populate this path with your AgentPi native source before building." >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA_DIR"

if [[ -d "$WORKSPACE_PATH" ]]; then
  BUILD_ARGS=(-workspace "$WORKSPACE_PATH")
else
  BUILD_ARGS=(-project "$PROJECT_PATH")
fi

xcodebuild \
  "${BUILD_ARGS[@]}" \
  -scheme AgentPi \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug/AgentPi.app"

echo "Built app: $APP_PATH"
