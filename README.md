<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PHBhdGggZD0iTTEyIDJ2MTAiLz48cGF0aCBkPSJNMTIgMTJsNiA2Ii8+PC9zdmc+">
  <img alt="AgentPi" src="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge">
</picture>

# AgentPi

### The Mission Control for AI Coding Agents

Monitor, orchestrate, and review **Claude Code**, **Codex CLI** & **[pi-mono](https://github.com/badlogic/pi-mono)** sessions — all in real time, all on your machine.

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
Live session updates via kqueue file-system watchers — zero polling.
Status indicators, token counts, tool activity feed, and context window usage at a glance.

### Multi-Provider Orchestration
Run Claude Code, Codex CLI, and pi-mono sessions side by side.
Launch parallel agents with manual prompts or AI-planned orchestration.

### Inline Diff Review
Split-pane diff viewer with syntax highlighting.
Built-in inline editor to review changes and send feedback directly to agents.

### Embedded Terminal
Full PTY terminal (SwiftTerm) inside each session card.
Resume or start sessions without ever leaving the app.

### Mobile Relay
Handoff tasks to remote agents from mobile devices.
Track task progress and manage artifacts across sessions.

</td>
<td width="50%" valign="top">

### DAG Workflow Engine
Execution graphs with parallel nodes, conditional branching, approval gates, and safe expression evaluation.

### Git Integration
Worktree management, branch-based session launching, pending changes preview, and inline diff review.

### Developer UX
Command palette (**Cmd+K**), web preview panel, plan view, global full-text search, drag-and-drop file attachments, and multi-column layouts.

### Customizable Themes
YAML themes with hot-reload. Ships with built-in themes: **Claude**, **Codex**, **Bat**, **Xcode**.
Notification sounds, menu bar or popover mode.

### Auto-Updates
Sparkle-powered updates with EdDSA signature verification.
Stay current without manual downloads.

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
│    WorktreeService ·  RuntimeUpdater  ·  RpcProcessPool          │
│    SearchIndexer   ·  StatsAggregator ·  PersistenceStore        │
└──────────────────────────────────────────────────────────────────┘
```

| Layer | Stack | Responsibility |
|:---|:---|:---|
| **Native Client** | Swift 6 / SwiftUI / AppKit | Real-time UI, file watching, terminal emulation, diff rendering |
| **Local Daemon** | Node.js 22 / Express 5 / WS | Session orchestration, workflow engine, RPC pool, persistence |
| **Protocol** | TypeScript 5.9 / Zod 4 | Shared type-safe schemas for client ↔ daemon communication |

---

## Project Structure

```
agentpi/
├── apps/
│   └── daemon/                       # Local Node.js server (Express + WebSocket)
│       └── src/modules/              # Session, Workflow, Terminal, Search, Stats ...
├── packages/
│   └── protocol/                     # Shared Zod schemas & TypeScript types
├── external/
│   └── AgentPi/                      # macOS native client (Swift / SwiftUI)
│       ├── app/modules/AgentPiCore/  # Core framework (120+ Swift sources)
│       └── build/                    # Release artifacts & DMG
├── scripts/                          # Build, seed, diagnostic scripts
├── docs/                             # Build, testing, troubleshooting guides
└── .github/workflows/                # CI/CD pipelines
```

---

## Tech Stack

| Component | Technology |
|:---|:---|
| **macOS Client** | Swift 6.0, SwiftUI, AppKit, Combine, `@Observable` macro |
| **Daemon** | Node.js 22, Express 5, WebSocket (ws), SQLite |
| **Protocol** | TypeScript 5.9, Zod 4 |
| **File Watching** | kqueue via DispatchSource (zero polling) |
| **Terminal** | SwiftTerm (PTY emulation) |
| **Diff Rendering** | PierreDiffsSwift (split-pane) |
| **Markdown** | swift-markdown-ui |
| **Syntax Highlighting** | HighlightSwift |
| **AI Integration** | ClaudeCodeSDK |
| **Auto-Updates** | Sparkle (EdDSA signed) |
| **Persistence** | GRDB.swift (SQLite ORM) |
| **Testing** | Vitest (daemon), XCTest (native client) |
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
| `DELETE` | `/v1/sessions/:id` | Close session |

</details>

<details>
<summary><strong>Workflows</strong></summary>

| Method | Endpoint | Description |
|:---|:---|:---|
| `POST` | `/v1/workflows` | Create workflow from DAG |
| `POST` | `/v1/workflows/:id/run` | Execute a workflow |
| `GET` | `/v1/workflows/runs/:runId` | Get run state |
| `POST` | `/v1/workflows/:id/validate` | Validate workflow graph |
| `POST` | `/v1/approvals/:id/decision` | Approve or reject a tool call |

</details>

<details>
<summary><strong>Other Endpoints</strong></summary>

| Method | Endpoint | Description |
|:---|:---|:---|
| `POST` | `/v1/terminals` | Start a PTY terminal |
| `POST` | `/v1/worktrees` | Create a git worktree |
| `GET` | `/v1/search?q=...` | Full-text search across sessions |
| `GET` | `/v1/stats/:id` | Session token & tool stats |
| `POST` | `/v1/runtime/update/check` | Check for runtime updates |
| `GET` | `/health` | Health check (no auth required) |

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

Drop a YAML file into `~/Library/Application Support/AgentPi/themes/` — changes apply instantly via hot-reload.

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

## pi-mono Compatibility

AgentPi supports [pi-mono](https://github.com/badlogic/pi-mono) — an open-source AI agent toolkit by [@badlogic](https://github.com/badlogic). Monitor pi-mono sessions alongside Claude Code and Codex in one unified hub.

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
