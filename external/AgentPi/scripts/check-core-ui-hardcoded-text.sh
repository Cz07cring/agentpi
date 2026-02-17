#!/usr/bin/env bash
set -euo pipefail

FILES=(
  "app/modules/AgentPiCore/Sources/AgentPi/UI/MultiSessionLaunchView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/MultiProviderMonitoringPanelView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/MonitoringCardView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/SettingsView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/CommandPaletteView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/WelcomeView.swift"
  "app/modules/AgentPiCore/Sources/AgentPi/UI/CLISessionsListView.swift"
)

pattern='Text\("[^"\\]*[A-Za-z][^"\\]*"\)|Button\("[^"\\]*[A-Za-z][^"\\]*"\)|\.help\("[^"\\]*[A-Za-z][^"\\]*"\)|alert\("[^"\\]*[A-Za-z][^"\\]*"\)|Picker\("[^"\\]*[A-Za-z][^"\\]*"'

matches="$(rg -n -e "$pattern" "${FILES[@]}" || true)"

if [[ -n "$matches" ]]; then
  echo "Found hardcoded UI text in core files. Use L10n.t/L10n.f instead:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "Core UI hardcoded text check passed."
