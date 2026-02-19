<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PHBhdGggZD0iTTEyIDJ2MTAiLz48cGF0aCBkPSJNMTIgMTJsNiA2Ii8+PC9zdmc+">
  <img alt="AgentPi" src="https://img.shields.io/badge/AgentPi-Mission_Control-7C3AED?style=for-the-badge">
</picture>

# AgentPi

**The Mission Control for AI Coding Agents**

Monitor, orchestrate, and review Claude Code, Codex CLI & [pi-mono](https://github.com/badlogic/pi-mono) sessions — all in real time, all on your machine.

**[English](README.md)** | **[中文](README.zh-CN.md)**

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

<!-- TODO: Add screenshot — ![AgentPi Hub](docs/assets/hub-screenshot.png) -->

</div>

---

## Why AgentPi?

Running multiple AI coding agents across projects is messy. Context windows fill up silently, tool calls pile up awaiting approval, and costs spiral without visibility.

**AgentPi provides a unified cockpit** — one screen to monitor every active session, review diffs inline, approve tool calls, launch parallel agents, and track token usage. Zero data ever leaves your machine.

## Features

<table>
<tr>
<td width="50%">

**Real-time Monitoring**
Live session updates via kqueue file-system watchers. Status, tokens, tool activity, and context usage at a glance.

**Multi-Provider Support**
Claude Code, Codex, and pi-mono sessions side by side. Launch parallel agents with manual prompts or AI-planned orchestration.

**Inline Diff Review**
Split-pane diff view with inline editor. Review changes and send feedback directly to Claude.

**Embedded Terminal**
Full PTY terminal (SwiftTerm) inside each session card. Resume or start sessions without leaving the app.

</td>
<td width="50%">

**DAG Workflow Engine**
Execution graphs with parallel nodes, conditional branching, approval gates, and safe expression evaluation.

**Git Integration**
Worktree management, branch-based session launching, inline diff review, pending changes preview.

**Developer UX**
Command palette (Cmd+K), web preview, plan view, global search, drag-and-drop file attachments.

**Customizable Themes**
YAML themes with hot-reload. Built-in: Claude, Codex, Bat, Xcode. Notification sounds, menu bar or popover mode.

</td>
</tr>
</table>

> **Privacy-First** — Runs entirely on your machine. Reads local session files, communicates over `localhost` only. No telemetry, no cloud, no tracking.

## Quick Start

### Prerequisites

| Requirement | Notes |
|---|---|
| **macOS 14.0+** | Xcode Command Line Tools required |
| **Node.js >= 22** | [Download](https://nodejs.org/) |
| **Claude Code CLI** | Installed & authenticated — [Setup guide](https://docs.anthropic.com/en/docs/claude-code) |
| **Codex CLI** *(optional)* | [Setup guide](https://openai.com/index/introducing-codex/) |

### Install & Run

```bash
# Clone
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

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     macOS Native Client                       │
│                  Swift 6 · SwiftUI · AppKit                   │
│                                                               │
│   Hub  ·  Diff View  ·  Terminal  ·  Cmd+K  ·  Settings      │
│                          │                                    │
│                CLISessionsViewModel                           │
│                (@MainActor · Combine)                         │
│                          │                                    │
│    SessionFileWatcher  ·  CodexFileWatcher  ·  ThemeWatcher   │
│             kqueue + byte-offset incremental reads            │
└──────────────┬───────────────────────────────────────────────┘
               │
               │  Reads ~/.claude/projects/{path}/{id}.jsonl
               │  Reads ~/.codex/sessions/{date}/{id}.jsonl
               │
               │  HTTP + WebSocket · localhost:43210
               ▼
┌──────────────────────────────────────────────────────────────┐
│                        Local Daemon                           │
│                 Node.js 22 · Express 5 · WS                   │
│                                                               │
│   Session Manager  ·  Workflow Engine  ·  Terminal Service     │
│   Worktree Service ·  Runtime Updater  ·  RPC Process Pool    │
│   Search Indexer   ·  Stats Aggregator ·  SQLite Storage      │
└──────────────────────────────────────────────────────────────┘
```

| Layer | Tech | Responsibility |
|---|---|---|
| **Native Client** | Swift 6 / SwiftUI / AppKit | Real-time UI, file watching, terminal emulation, diff rendering |
| **Local Daemon** | Node.js 22 / Express 5 / WS | Session orchestration, workflow engine, RPC pool, persistence |
| **Protocol** | TypeScript 5.9 / Zod 4 | Shared type-safe schemas for client-daemon communication |

## Project Structure

```
agentpi/
├── apps/
│   └── daemon/                    # Node.js local server (Express + WebSocket)
│       └── src/modules/           # Session, Workflow, Terminal, Search, Stats, ...
├── packages/
│   └── protocol/                  # Shared Zod schemas & types (TypeScript)
├── external/
│   └── AgentPi/                   # macOS native client (Swift / SwiftUI)
│       └── app/modules/AgentPiCore/  # Core framework (110+ Swift sources)
├── scripts/                       # Build, seed, diagnostic scripts
└── docs/                          # Build, testing, troubleshooting guides
```

## Tech Stack

| Component | Technology |
|---|---|
| **macOS Client** | Swift 6.0, SwiftUI, AppKit, Combine, `@Observable` |
| **Daemon** | Node.js 22, Express 5, WebSocket, SQLite |
| **Protocol** | TypeScript 5.9, Zod 4 |
| **File Watching** | kqueue via DispatchSource (zero polling) |
| **Terminal** | SwiftTerm (PTY emulation) |
| **Diff Rendering** | PierreDiffsSwift (split-pane) |
| **Markdown** | swift-markdown-ui, PierreMD |
| **AI Integration** | ClaudeCodeSDK |
| **Auto-Updates** | Sparkle (EdDSA signed) |
| **Testing** | Vitest (daemon), XCTest (macOS) |
| **CI/CD** | GitHub Actions |

## API Overview

The daemon exposes a REST + WebSocket API on `localhost:43210`.

<details>
<summary><strong>Sessions</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
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
|---|---|---|
| `POST` | `/v1/workflows` | Create workflow from DAG |
| `POST` | `/v1/workflows/:id/run` | Execute a workflow |
| `GET` | `/v1/workflows/runs/:runId` | Get run state |
| `POST` | `/v1/workflows/:id/validate` | Validate workflow graph |
| `POST` | `/v1/approvals/:id/decision` | Approve or reject a tool call |

</details>

<details>
<summary><strong>Other Endpoints</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/v1/terminals` | Start a PTY terminal |
| `POST` | `/v1/worktrees` | Create a git worktree |
| `GET` | `/v1/search?q=...` | Full-text search across sessions |
| `GET` | `/v1/stats/:id` | Session token & tool stats |
| `POST` | `/v1/runtime/update/check` | Check for runtime updates |
| `GET` | `/health` | Health check (no auth) |

</details>

**WebSocket** — `ws://localhost:43210/ws?token=...`
Real-time events: session state, workflow progress, approval requests, terminal output, runtime updates.

## Scripts

| Script | Description |
|---|---|
| `npm run dev` | Start daemon in dev mode (watch) |
| `npm run dev:doctor` | Diagnose environment & ports |
| `npm run build` | Build all workspaces |
| `npm run typecheck` | TypeScript type checking |
| `npm test` | Unit & contract tests (Vitest) |
| `npm run mac:build` | Build macOS app (xcodebuild) |
| `npm run mac:open` | Launch macOS app |
| `npm run mac:demo` | Seed demo data + open app |
| `npm run test:release-gate` | Full release gate (typecheck + test + build) |

## Keyboard Shortcuts

| Shortcut | Action | Shortcut | Action |
|---|---|---|---|
| **Cmd+K** | Command palette | **Cmd+N** | New session |
| **Cmd+B** | Toggle sidebar | **Cmd+,** | Settings |
| **Cmd+[** | Previous session | **Cmd+]** | Next session |
| **Escape** | Dismiss / close | **Return** | Send inline comment (diff) |

## Security

All communication stays on `127.0.0.1`. No network egress.

- **Token auth** on all routes except `/health` — via `x-agentpi-token` header or `Authorization: Bearer`
- **CORS** restricted to `localhost` origins
- **WebSocket auth** via header or query parameter
- **Audit logging** — every request logged to local SQLite
- **Safe evaluation** — workflow conditions use a sandboxed evaluator, no `eval()`

Set your token:

```bash
export AGENTPI_DAEMON_TOKEN="your-secret-token"
```

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

Built-in themes: **Claude** | **Codex** | **Bat** | **Xcode**

## pi-mono Compatibility

AgentPi is compatible with [pi-mono](https://github.com/badlogic/pi-mono) — an open-source AI agent toolkit by [@badlogic](https://github.com/badlogic). Monitor pi-mono sessions alongside Claude Code and Codex in one unified hub.

## Contributing

1. Fork & create a feature branch
2. Keep PRs focused — one feature or fix per PR
3. Validate before submitting: `npm run test:release-gate`
4. Submit PR with motivation, approach, and test results

See [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md) for details.

## Documentation

| Document | Description |
|---|---|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS build & branding guide |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | Testing strategy & matrix |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Common issues & debugging |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | Architecture deep-dive |

## License

[MIT](LICENSE) &copy; 2025 ring
