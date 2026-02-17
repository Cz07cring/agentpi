<div align="center">

**[English](README.md)** | **[中文](README.zh-CN.md)**

# AgentPi

### The Mission Control for Your AI Coding Agents

A local-first platform for monitoring and orchestrating Claude Code, Codex CLI & [pi-mono](https://github.com/badlogic/pi-mono) sessions in real-time.
Native macOS client + local daemon. Zero data leaves your machine.

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

</div>

## Why AgentPi?

Running multiple AI coding agents across different projects and branches is messy. You lose track of which agent is doing what, context windows fill up silently, tool calls pile up awaiting approval, and costs spiral without visibility.

**AgentPi gives you a unified cockpit.** One screen to monitor every active Claude Code, Codex, and pi-mono session, review diffs inline, approve tool calls, launch parallel agents, and track token usage — all without any of your code or conversation data ever leaving your machine.

## Highlights

- **Real-time Session Monitoring** — Watch all active sessions update live via kqueue file-system watchers. No polling. Status, token counts, tool activity, and context window usage at a glance.
- **Multi-Provider, Multi-Session** — Run Claude Code, Codex, and [pi-mono](https://github.com/badlogic/pi-mono) sessions side by side. Launch parallel agents with manual prompts or AI-planned orchestration (Smart mode).
- **Inline Diff Review** — Full split-pane diff view with an inline editor. Review changes and send feedback directly to Claude without switching windows.
- **Embedded Terminal** — Full PTY terminal (SwiftTerm) inside each session card. Resume or start sessions without leaving the app.
- **Privacy-First** — Runs entirely on your machine. Reads local session files, communicates over localhost only. No telemetry, no cloud, no tracking.
- **Workflow Engine** — DAG-based workflow execution with parallel nodes, conditional branching, approval gates, and safe expression evaluation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS Native Client                       │
│                  (Swift / SwiftUI / AppKit)                  │
│                                                              │
│  Hub View · Diff View · Terminal · Cmd Palette · Settings    │
│                          │                                   │
│                CLISessionsViewModel                          │
│                (@MainActor, Combine)                         │
│                          │                                   │
│    SessionFileWatcher · CodexFileWatcher · ThemeFileWatcher   │
│    (kqueue + byte-offset incremental reads)                  │
└──────────┬──────────────────────────────────────────────────┘
           │
  ~/.claude/projects/{path}/{id}.jsonl
  ~/.codex/sessions/{date}/{id}.jsonl
           │
           │  HTTP + WebSocket (localhost:43210)
           ▼
┌─────────────────────────────────────────────────────────────┐
│                       Local Daemon                           │
│                  (Node.js / Express / WS)                    │
│                                                              │
│  Session Manager · Workflow Engine · Terminal Service         │
│  Worktree Service · Runtime Updater · RPC Pool               │
│  Search Indexer · Storage (SQLite) · Stats Aggregator        │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Tech | Role |
|-------|------|------|
| **Native Client** | Swift 6 / SwiftUI | Real-time UI, file watching, terminal emulation, diff rendering |
| **Local Daemon** | Node.js 22 / Express / WS | Session orchestration, workflow engine, RPC pool, persistence |
| **Protocol** | TypeScript / Zod | Shared type-safe schemas for client-daemon communication |

## Features

**Session Management** — Real-time monitoring with status tracking (Thinking / Executing Tool / Awaiting Approval / Waiting for User / Idle), context window visualization, token & cost tracking, custom session naming (SQLite-backed).

**Hub Layouts** — Single (full-size + side panel), List (grouped by provider), 2-Column grid, 3-Column grid. Any card can be maximized.

**Multi-Session Launcher** — Launch parallel sessions across providers. Manual mode (direct prompts) or Smart mode (AI-planned task orchestration).

**Git Integration** — Worktree creation/deletion from UI, branch-based session launching, inline diff review, pending changes preview.

**Developer Experience** — Command palette (Cmd+K), web preview with auto dev server, plan view with syntax highlighting, global search, drag-and-drop file attachments.

**Customization** — YAML themes with hot-reload, built-in themes (Claude, Codex, Bat, Xcode), configurable notification sounds, menu bar or popover display modes.

## Quick Start

### Prerequisites

- **macOS 14.0+** with Xcode Command Line Tools
- **Node.js >= 22** ([download](https://nodejs.org/))
- **Claude Code CLI** installed and authenticated ([setup](https://docs.anthropic.com/en/docs/claude-code))
- **Codex CLI** (optional) ([setup](https://openai.com/index/introducing-codex/))

### Install & Run

```bash
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi
npm install

# Start daemon (port 43210)
npm run dev

# Build & open macOS app
npm run mac:build
npm run mac:open

# Or one-shot: seed demo + open
npm run mac:demo
```

## Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start daemon in dev mode |
| `npm run dev:doctor` | Diagnose environment & ports |
| `npm run typecheck` | TypeScript type checking |
| `npm test` | Unit & contract tests |
| `npm run build` | Build all workspaces |
| `npm run mac:build` | Build macOS app |
| `npm run mac:open` | Open macOS app |
| `npm run mac:demo` | Seed demo data + open |
| `npm run test:release-gate` | Full release gate (typecheck + test + mac:build + build) |

## Keyboard Shortcuts

| Shortcut | Action | Shortcut | Action |
|----------|--------|----------|--------|
| **Cmd+K** | Command palette | **Cmd+N** | New session |
| **Cmd+B** | Toggle sidebar | **Cmd+,** | Settings |
| **Cmd+\[** | Previous session | **Cmd+\]** | Next session |
| **Escape** | Dismiss / close | **Return** | Send inline comment (diff) |

## Security

- **Token auth** on all routes except `/health` (`x-agentpi-token` header or `Bearer` token)
- **CORS** restricted to `localhost`
- **WebSocket auth** via header or query on `/ws`
- **Audit logging** to local SQLite
- **Zero network egress** — all on `127.0.0.1`

Set token via `AGENTPI_DAEMON_TOKEN` environment variable.

## pi-mono Compatibility

AgentPi is compatible with [pi-mono](https://github.com/badlogic/pi-mono) — an open-source AI agent toolkit by [@badlogic](https://github.com/badlogic) featuring a coding agent CLI, unified multi-provider LLM API, TUI/Web UI libraries, Slack bot, and vLLM pod management.

AgentPi monitors and manages pi-mono coding agent sessions alongside Claude Code and Codex — one hub for all your AI coding agents.

## Project Structure

```
agentpi/
├── apps/daemon/           # Local daemon (Node.js + Express + WebSocket)
├── packages/protocol/     # Shared Zod schemas (TypeScript)
├── external/AgentPi/      # macOS native client (Swift / SwiftUI)
│   └── app/modules/AgentPiCore/  # Core package (110+ Swift source files)
├── docs/                  # Build, testing, troubleshooting guides
└── scripts/               # Build, seed, diagnostic scripts
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| **macOS Client** | Swift 6.0, SwiftUI, AppKit, Combine |
| **Daemon** | Node.js 22, Express 5, WebSocket |
| **Protocol** | TypeScript 5.9, Zod 4 |
| **Persistence** | SQLite (GRDB.swift + custom store) |
| **File Watching** | kqueue (DispatchSource) |
| **Terminal** | SwiftTerm (PTY emulation) |
| **Diff Rendering** | PierreDiffsSwift |
| **AI Integration** | ClaudeCodeSDK |
| **Auto-Updates** | Sparkle (EdDSA) |
| **Testing** | Vitest, XCTest |
| **CI/CD** | GitHub Actions |

## Custom Themes

Place YAML files in `~/Library/Application Support/AgentPi/themes/` — changes hot-reload instantly.

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

## Contributing

1. Fork & create a feature branch
2. Keep PRs focused — one feature or fix per PR
3. Validate: `npm run test:release-gate`
4. Submit PR with motivation, approach, and test results

See [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md) for details.

## Documentation

| Doc | Description |
|-----|-------------|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS build & branding |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | Testing strategy |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Troubleshooting |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | Architecture deep-dive |

## License

[MIT](LICENSE) &copy; 2026 ring
