# AgentPi Tri-Platform Copy & UX Spec

## Scope
- Providers: `Claude + Codex + AgentPi`
- Surfaces: Launcher / Welcome / Command Palette / Hub Filter
- Goal: make copy state-driven and remove 2-provider legacy wording.

## State -> Copy -> Key Mapping

| State | UI position | Key | Example (zh-Hans) |
|---|---|---|---|
| `selectedCount = 0` | Prompt placeholder | `launch.prompt.select_provider` | `请选择提供方...` |
| `selectedCount = 1` + Claude | Prompt placeholder | `launch.prompt.claude` | `可选：Claude 会话初始提示词...` |
| `selectedCount = 1` + Codex | Prompt placeholder | `launch.prompt.codex` | `可选：Codex 会话初始提示词...` |
| `selectedCount = 1` + AgentPi | Prompt placeholder | `launch.prompt.agentpi` | `可选：AgentPi 会话初始提示词...` |
| `selectedCount >= 2` | Prompt placeholder | `launch.prompt.shared_count` | `可选：3 个会话共用的初始提示词...` |
| `selectedCount >= 2` | Badge | `launch.badge.shared_prompt` | `共享提示词` |
| any | Selection line | `launch.selection.status_format` | `已选择 3 个 Agent：Claude、Codex、AgentPi` |
| `selectedCount = 0` | Disabled reason | `launch.disabled.select_agent` | `请先选择至少 1 个 Agent` |
| `workMode = worktree` + selected | Hint line | `launch.worktree.per_agent_hint` | `将为每个 Agent 创建独立 worktree` |
| providers selected | Launch button | `launch.button.providers_format` | `启动 Claude + Codex + AgentPi` |

## Key Changes

### Added
- `launch.selection.none`
- `launch.selection.status_format`
- `launch.selection.separator`
- `launch.badge.shared_prompt`
- `launch.worktree.per_agent_hint`
- `launch.disabled.select_agent`

### Existing keys now required in tri-provider flow
- `launch.prompt.shared_count`
- `launch.prompt.codex`
- `launch.button.providers_format`
- `hub.filter.codex`
- `launch.attach_files`
- `launch.mode.local`
- `launch.mode.worktree`
- `launch.reset`

## Localization Gate
- Script: `scripts/check-localization-keys.sh`
- CI: `.github/workflows/localization.yml`
- Rule: `en/zh-Hans/ko/ja/vi` must have identical key sets.
