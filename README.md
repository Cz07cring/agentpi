<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PHBhdGggZD0iTTEyIDJ2MTAiLz48cGF0aCBkPSJNMTIgMTJsNiA2Ii8+PC9zdmc+">
  <img alt="AgentPi" src="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge">
</picture>

# AgentPi

### The Mission Control for AI Coding Agents

Monitor, orchestrate, and review **Claude Code**, **Codex CLI**, and **[pi-mono](https://github.com/badlogic/pi-mono)** sessions — all in real time, all on your machine.

**[English](README.md)** | **[中文](README.zh-CN.md)**

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

</div>

<br>

> **Privacy-first.** All data stays on your machine. No telemetry, no cloud, no tracking. Communication is `localhost` only.

---

## Why AgentPi?

Running multiple AI coding agents across projects gets messy fast. Context windows fill up silently, tool calls pile up awaiting approval, and costs spiral without visibility.

**AgentPi gives you a unified cockpit** — one screen to monitor every active session, review diffs inline, approve tool calls, launch parallel agents, and track token usage across providers.

---

## Features

<table>
<tr>
<td width="50%" valign="top">

### Real-time Monitoring
Live session updates via kqueue file-system watchers — zero polling, byte-offset incremental reads.
Status indicators, token counts, tool activity feed, and context window usage at a glance.

### Multi-Provider Orchestration
Run Claude Code, Codex CLI, and pi-mono sessions side by side — all as first-class citizens.
Launch parallel agents with manual prompts or AI-planned orchestration across git worktrees.

### Inline Diff Review
Split-pane diff viewer with syntax highlighting.
Built-in inline editor to review changes and send feedback directly to agents.

### Embedded Terminal
Full PTY terminal (SwiftTerm) inside each session card.
Resume or start sessions without ever leaving the app.

### Mobile Relay & `happy` CLI
One-click handoff of tasks between providers (Claude &harr; Codex &harr; Pi).
Generates JSONL + Markdown handoff artifacts preserving full session context.
Powered by the [`happy`](#mobile-relay--happy-cli-1) CLI wrapper with intelligent detection and fallback.

### Batch Task Runner
Run non-interactive one-off commands from configurable templates.
Real-time stdout/stderr streaming with smart ANSI stripping, stop/rerun controls, elapsed time tracking, and auto-scroll.
One-click **Stop** button sends SIGTERM; 20-second watchdog prevents "frozen UI" for buffered-output CLIs.
CI-safe execution (`CI=1`, `GIT_TERMINAL_PROMPT=0`) with automatic `happy` relay fallback.

</td>
<td width="50%" valign="top">

### Smart Orchestration
AI-driven parallel session planning via ClaudeCodeSDK.
Three modes: **Parallel**, **Prototype**, and **Exploration**.
Claude generates a structured plan, AgentPi spawns sessions across git worktrees automatically.

### DAG Workflow Engine
Execution graphs with parallel nodes, conditional branching, approval gates, and safe expression evaluation.

### Unified Command Templates
Single template system for all providers and intents — `start_session`, `resume_session`, `batch_run`, `mobile_relay`.
Supports placeholders (`{{prompt}}`, `{{project_path}}`, `{{handoff_jsonl}}`), custom executables, drag-to-reorder, enable/disable.

### Git Integration
Worktree management, branch-based session launching, pending changes preview, and inline diff review.

### Developer UX
Command palette (**Cmd+K**), web preview panel, plan view, global full-text search, drag-and-drop file attachments, dev server management, proxy injection, and multi-column layouts.

### Customizable Themes & i18n
YAML themes with hot-reload. Built-in themes: **Claude**, **Codex**, **Bat**, **Xcode**.
Localized in 5 languages: English, 简体中文, 日本語, 한국어, Tiếng Việt.

### Auto-Updates
Sparkle-powered updates with EdDSA signature verification.
One-command local release flow with DMG distribution.

</td>
</tr>
</table>

---

## Quick Start

### Prerequisites

| Requirement | Notes |
|:---|:---|
| **macOS 14.0+** | Xcode Command Line Tools required |
| **Node.js >= 22** | [Download](https://nodejs.org/) |
| **Claude Code CLI** | Installed & authenticated — [Setup guide](https://docs.anthropic.com/en/docs/claude-code) |
| **Codex CLI** *(optional)* | [Setup guide](https://openai.com/index/introducing-codex/) |
| **happy CLI** *(optional)* | Enables cross-provider Mobile Relay |

### Install & Run

```bash
# Clone the repository
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi && npm install

# Start the local daemon (port 43210)
npm run dev

# Build & launch the macOS app
npm run mac:build && npm run mac:open
```

Or try it instantly with demo data:

```bash
npm run mac:demo
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      macOS Native Client                         │
│                   Swift 6 · SwiftUI · AppKit                     │
│                                                                  │
│    Hub  ·  Diff View  ·  Terminal  ·  Cmd+K  ·  Settings         │
│                           │                                      │
│                 CLISessionsViewModel                             │
│                 (@MainActor · Combine)                           │
│                           │                                      │
│     SessionFileWatcher  ·  CodexFileWatcher  ·  ThemeWatcher     │
│              kqueue + byte-offset incremental reads              │
└───────────────┬──────────────────────────────────────────────────┘
                │
                │  ~/.claude/projects/{path}/{id}.jsonl
                │  ~/.codex/sessions/{date}/{id}.jsonl
                │
                │  HTTP + WebSocket · localhost:43210
                ▼
┌──────────────────────────────────────────────────────────────────┐
│                         Local Daemon                             │
│                  Node.js 22 · Express 5 · WS                     │
│                                                                  │
│    SessionManager  ·  WorkflowEngine  ·  TerminalService         │
│    WorktreeService ·  PiRuntimeUpdater ·  RpcProcessPool         │
│    SearchIndexer   ·  StatsAggregator  ·  PersistenceStore       │
│    DevServerService ·  DaemonEventBus                            │
└──────────────────────────────────────────────────────────────────┘
```

| Layer | Stack | Responsibility |
|:---|:---|:---|
| **Native Client** | Swift 6 / SwiftUI / AppKit | Real-time UI, file watching, terminal emulation, diff rendering |
| **Local Daemon** | Node.js 22 / Express 5 / WS | Session orchestration, workflow engine, RPC pool, persistence |
| **Protocol** | TypeScript 5.9 / Zod 4 | Shared type-safe schemas for client ↔ daemon communication |

---

## Mobile Relay & `happy` CLI

AgentPi integrates with the **`happy` CLI wrapper** to enable seamless cross-provider handoff:

```
Claude  → Codex    happy codex --project {{project_path}} --handoff {{handoff_jsonl}}
Claude  → Pi       happy pi --project {{project_path}} --handoff {{handoff_jsonl}}
Codex   → Claude   happy --project {{project_path}} --handoff {{handoff_jsonl}}
Codex   → Pi       happy pi --project {{project_path}} --handoff {{handoff_jsonl}}
Pi      → Claude   happy --project {{project_path}} --handoff {{handoff_jsonl}}
Pi      → Codex    happy codex --project {{project_path}} --handoff {{handoff_jsonl}}
```

**How it works:**

1. Click the relay button on any active session
2. AgentPi captures the session's prompt, conversation history, project path, and git branch
3. Two handoff artifacts are written to `{project}/.agentpi/mobile-relay/{YYYY-MM-DD}/`:
   - **JSONL** — machine-readable state (session ID, providers, prompt, timestamps)
   - **Markdown** — human-readable summary with context, diffs, and instructions
4. The target agent launches via `happy` with full context preserved

**Smart Fallback:** When a `happy` relay command is used as a batch template, AgentPi automatically detects it and falls back to the native CLI (`claude`, `codex`, `pi`), ensuring commands run reliably without the external terminal dependency.

---

## Smart Orchestration

AgentPi uses **ClaudeCodeSDK** to enable AI-driven parallel session planning. Describe your goal and Claude generates a structured orchestration plan:

```json
{
  "modulePath": "/path/to/project",
  "sessions": [
    {
      "description": "Implement user authentication module",
      "branchName": "feat/auth-module",
      "sessionType": "parallel",
      "prompt": "Implement JWT-based authentication..."
    },
    {
      "description": "Add database migration scripts",
      "branchName": "feat/db-migrations",
      "sessionType": "parallel",
      "prompt": "Create migration scripts for..."
    }
  ]
}
```

AgentPi spawns each session in its own **git worktree**, running them in parallel across branches:

| Mode | Use Case |
|:---|:---|
| **Parallel** | Same task split across different modules or files |
| **Prototype** | Same goal with different implementation approaches |
| **Exploration** | Related but distinct features explored simultaneously |

---

## Command Templates

All session launching, batch execution, and mobile relay commands are driven by a **unified template system** (`AgentCommandTemplateV1`). Templates are configurable per provider and intent.

### Template Intents

| Intent | Description |
|:---|:---|
| `start_session` | Launch an interactive PTY session |
| `resume_session` | Resume an existing session |
| `batch_run` | One-off non-interactive command |
| `mobile_relay` | Mobile handoff via external terminal |

### Built-in Templates

| Provider | Template | Intent | Command |
|:---|:---|:---|:---|
| Claude | Session Fast | start_session | `claude --dangerously-skip-permissions {{prompt}}` |
| Claude | Batch Fast | batch_run | `claude -p {{prompt}} --dangerously-skip-permissions` |
| Claude | Batch Stream Verbose | batch_run | `claude -p {{prompt}} --output-format stream-json --verbose` |
| Claude | Mobile Relay | mobile_relay | `happy --project {{project_path}} --handoff {{handoff_jsonl}}` |
| Codex | Session Fast | start_session | `codex {{prompt}}` |
| Codex | Session Aggressive | start_session | `codex --full-auto {{prompt}}` |
| Codex | Batch JSONL | batch_run | `codex exec {{prompt}} --json` |
| Codex | Mobile Relay | mobile_relay | `happy codex --project {{project_path}} --handoff {{handoff_jsonl}}` |
| Pi | Session Stable | start_session | `pi --no-extensions --no-skills --no-themes {{prompt}}` |
| Pi | Batch Fast | batch_run | `pi -p {{prompt}} --no-extensions --no-skills --no-themes` |
| Pi | Mobile Relay | mobile_relay | `happy pi --project {{project_path}} --handoff {{handoff_jsonl}}` |

### Placeholders

| Placeholder | Replaced With |
|:---|:---|
| `{{prompt}}` | User prompt text |
| `{{project_path}}` | Absolute path to the project directory |
| `{{handoff_jsonl}}` | Path to the generated JSONL handoff artifact |
| `{{handoff_markdown}}` | Path to the generated Markdown handoff artifact |
| `{{session_id}}` | Current session ID |
| `{{branch}}` | Current git branch name |

Create custom templates, reorder them, and set per-provider defaults from **Settings → Command Templates**.

---

## Batch Task Runner

The batch runner executes non-interactive commands defined by `batch_run` templates. Unlike interactive sessions, batch tasks run as headless subprocesses with piped I/O.

- **Real-time streaming** — stdout and stderr are captured and displayed live in the Batch Runs panel with smart ANSI/control-sequence stripping for clean output
- **Stop & Cancel** — one-click **Stop** button sends SIGTERM to the running process; cancelled tasks show "Cancelled" status (exit code 130) instead of generic failure
- **Watchdog timer** — if no visible output appears within 20 seconds, a helpful hint is displayed so the UI never looks frozen
- **Auto-scroll** — output panel automatically scrolls to the latest line as new data arrives
- **Waiting state** — when CLI output is buffered (e.g. `claude -p` in non-stream mode), the panel shows a live elapsed-time counter and chunk count
- **Process lifecycle** — each task captures its PID immediately after launch; rerun re-launches from the same template and context
- **`happy` auto-detection** — if a `happy` relay command is used as a batch template, AgentPi automatically falls back to the native CLI for local execution
- **CI-safe environment** — batch tasks run with `CI=1`, `GIT_TERMINAL_PROMPT=0`, and `GIT_ASKPASS=/usr/bin/false` to prevent interactive prompts from blocking headless execution

---

## Proxy Support

AgentPi supports configurable proxy injection for CLI sessions. When enabled, proxy environment variables (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`) are automatically set in the spawned process environment.

Configure proxy settings in **Settings → Network** or via `ProxyEnvironment` defaults.

---

## Project Structure

```
agentpi/
├── apps/
│   └── daemon/                       # Local Node.js server (Express + WebSocket)
│       └── src/modules/              # Session, Workflow, Terminal, Search, Stats, DevServer
├── packages/
│   └── protocol/                     # Shared Zod schemas & TypeScript types
├── external/
│   └── AgentPi/                      # macOS native client (Swift / SwiftUI)
│       └── app/modules/AgentPiCore/  # Core framework (120+ Swift sources)
│           └── Sources/AgentPi/
│               ├── Configuration/    # Service locator, defaults, environment
│               ├── Design/           # Theme system (YAML parsing, hot-reload)
│               ├── Intelligence/     # Smart orchestration via ClaudeCodeSDK
│               ├── Models/           # Session, state, cost, relay, template models
│               ├── Services/         # File watchers, Git, search, terminal, batch, relay
│               ├── UI/              # 40+ SwiftUI views
│               ├── ViewModels/      # @MainActor view models
│               ├── Utils/           # Logging, proxy, scoring, L10n
│               └── Resources/       # Localization (en, zh-Hans, ja, ko, vi)
├── scripts/                          # Build, seed, diagnostic scripts
├── docs/                             # Build, testing, troubleshooting guides
└── .github/workflows/                # CI/CD pipelines
```

---

## Tech Stack

| Component | Technology |
|:---|:---|
| **macOS Client** | Swift 6.0, SwiftUI, AppKit, Combine, `@Observable` macro |
| **Concurrency** | Swift actors, `async/await`, `withTaskGroup`, `@MainActor` |
| **Daemon** | Node.js 22, Express 5, WebSocket (`ws`), SQLite (`node:sqlite`) |
| **Protocol** | TypeScript 5.9, Zod 4 |
| **Persistence** | GRDB.swift (client) + `node:sqlite` (daemon) |
| **File Watching** | kqueue via DispatchSource — zero polling, byte-offset incremental reads |
| **Terminal** | SwiftTerm (PTY emulation) |
| **Diff Rendering** | PierreDiffsSwift (split-pane with inline editor) |
| **Markdown** | swift-markdown-ui |
| **Syntax Highlighting** | HighlightSwift |
| **Theme Parsing** | Yams (YAML hot-reload) |
| **AI Integration** | ClaudeCodeSDK 1.2.4 |
| **CLI Compatibility** | `happy` wrapper (auto-detection & native fallback) |
| **Auto-Updates** | Sparkle (EdDSA signed) |
| **Testing** | Vitest (daemon/protocol), XCTest (macOS client) |
| **Monorepo** | npm workspaces |
| **CI/CD** | GitHub Actions |

---

## API Overview

The daemon exposes a REST + WebSocket API on `localhost:43210`.

<details>
<summary><strong>Sessions</strong></summary>

| Method | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/v1/sessions` | List active sessions |
| `POST` | `/v1/sessions` | Create a new session |
| `POST` | `/v1/sessions/:id/prompt` | Send a user prompt |
| `POST` | `/v1/sessions/:id/steer` | Steer a running agent |
| `POST` | `/v1/sessions/:id/follow-up` | Follow-up prompt |
| `POST` | `/v1/sessions/:id/abort` | Abort the running agent |
| `POST` | `/v1/sessions/:id/wait-idle` | Block until session idle (max 60s) |
| `GET` | `/v1/sessions/:id/state` | Get full session state |
| `GET` | `/v1/sessions/:id/runtime-state` | Get runtime binding state |
| `DELETE` | `/v1/sessions/:id` | Close session |

</details>

<details>
<summary><strong>Workflows & Approvals</strong></summary>

| Method | Endpoint | Description |
|:---|:---|:---|
| `POST` | `/v1/workflows` | Create workflow from DAG |
| `POST` | `/v1/workflows/:id/run` | Execute a workflow |
| `GET` | `/v1/workflows/runs/:runId` | Get run state |
| `POST` | `/v1/workflows/:id/validate` | Validate workflow graph |
| `POST` | `/v1/approvals/:id/decision` | Approve or reject a tool call |

</details>

<details>
<summary><strong>Terminals, Dev Servers & System</strong></summary>

| Method | Endpoint | Description |
|:---|:---|:---|
| `POST` | `/v1/terminals` | Start a PTY terminal |
| `POST` | `/v1/terminals/:id/input` | Send input to terminal |
| `DELETE` | `/v1/terminals/:id` | Stop terminal |
| `POST` | `/v1/dev-servers` | Start dev server (npm/pnpm/yarn/bun) |
| `DELETE` | `/v1/dev-servers/:id` | Stop dev server |
| `POST` | `/v1/worktrees` | Create a git worktree |
| `DELETE` | `/v1/worktrees/:id` | Remove a git worktree |
| `GET` | `/v1/search?q=...` | Full-text search across sessions |
| `GET` | `/v1/stats/:id` | Session token & tool stats |
| `POST` | `/v1/runtime/update/check` | Check for runtime updates |
| `POST` | `/v1/runtime/update/apply` | Apply runtime updates |
| `GET` | `/health` | Health check (no auth required) |
| `GET` | `/health/details` | Detailed health (uptime, connections, PID) |

</details>

**WebSocket** — `ws://localhost:43210/ws?token=...`
Real-time events: session state, workflow progress, approval requests, terminal output, runtime updates.

---

## Scripts

| Script | Description |
|:---|:---|
| `npm run dev` | Start daemon in dev mode (file watching) |
| `npm run dev:doctor` | Diagnose environment & ports |
| `npm run build` | Build all workspaces |
| `npm run typecheck` | TypeScript type checking |
| `npm test` | Unit & contract tests (Vitest) |
| `npm run mac:build` | Build macOS app (xcodebuild) |
| `npm run mac:open` | Launch macOS app |
| `npm run mac:demo` | Seed demo data + open app |
| `npm run test:release-gate` | Full release gate (typecheck + test + mac:build + build) |

---

## Keyboard Shortcuts

| Shortcut | Action | Shortcut | Action |
|:---|:---|:---|:---|
| **Cmd+K** | Command palette | **Cmd+N** | New session |
| **Cmd+B** | Toggle sidebar | **Cmd+,** | Settings |
| **Cmd+[** | Previous session | **Cmd+]** | Next session |
| **Escape** | Dismiss / close | **Return** | Send inline comment (diff view) |

---

## Security

All communication stays on `127.0.0.1`. Zero network egress.

| Mechanism | Detail |
|:---|:---|
| **Token Auth** | Required on all routes except `/health` via `x-agentpi-token` header or `Authorization: Bearer` |
| **CORS** | Restricted to `localhost` origins |
| **WebSocket Auth** | Token via header or query parameter |
| **Audit Logging** | Every request logged to local SQLite |
| **Safe Evaluation** | Workflow conditions use a sandboxed evaluator — no `eval()` |

```bash
export AGENTPI_DAEMON_TOKEN="your-secret-token"
```

---

## Custom Themes

Drop a YAML file into `~/Library/Application Support/AgentPi/Themes/` — changes apply instantly via hot-reload.

```yaml
name: My Theme
version: 1
author: Your Name
colors:
  brand:
    primary: "#7C3AED"
    secondary: "#6D28D9"
  backgrounds:
    dark: "#1A1A2E"
    light: "#FFFFFF"
```

Built-in themes: **Claude** · **Codex** · **Bat** · **Xcode**

---

## Provider Compatibility

AgentPi treats all providers as first-class citizens:

| Provider | Session Monitoring | Batch Execution | Mobile Relay | Smart Orchestration |
|:---|:---:|:---:|:---:|:---:|
| **Claude Code** | &#10003; | &#10003; | &#10003; | &#10003; |
| **Codex CLI** | &#10003; | &#10003; | &#10003; | — |
| **pi-mono** | &#10003; | &#10003; | &#10003; | — |
| **`happy` CLI** | — | &#10003; (fallback) | &#10003; (wrapper) | — |

[pi-mono](https://github.com/badlogic/pi-mono) is an open-source AI agent toolkit by [@badlogic](https://github.com/badlogic).
The `happy` CLI wrapper enables seamless cross-provider relay with intelligent command detection and automatic native fallback.

---

## Contributing

1. Fork the repo & create a feature branch
2. Keep PRs focused — one feature or fix per PR
3. Run the release gate before submitting: `npm run test:release-gate`
4. Open a PR with clear motivation, approach, and test results

See [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md) for details.

---

## Documentation

| Document | Description |
|:---|:---|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS build & branding guide |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | Testing strategy & coverage matrix |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Common issues & debugging |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | Architecture deep-dive |

---

<div align="center">

[MIT License](LICENSE) &copy; 2026 ring

</div>
