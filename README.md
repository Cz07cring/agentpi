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

<br />

<img width="1913" height="1079" alt="AgentPi Hub" src="https://github.com/user-attachments/assets/99518d02-8ca6-458a-900c-bfd1f4e57419" />

</div>

<br />

## Why AgentPi?

Running multiple AI coding agents across different projects and branches is messy. You lose track of which agent is doing what, context windows fill up silently, tool calls pile up awaiting approval, and costs spiral without visibility.

**AgentPi gives you a unified cockpit.** One screen to monitor every active Claude Code and Codex session, review diffs inline, approve tool calls, launch parallel agents, and track token usage — all without any of your code or conversation data ever leaving your machine.

<br />

## Highlights

<table>
<tr>
<td width="50%" valign="top">

**Real-time Session Monitoring**
Watch all active sessions update live via kqueue file-system watchers. No polling. Status, token counts, tool activity, and context window usage — at a glance.

</td>
<td width="50%" valign="top">

**Multi-Provider, Multi-Session**
Run Claude Code, Codex, and [pi-mono](https://github.com/badlogic/pi-mono) sessions side by side. Launch parallel agents across providers with manual prompts or AI-planned orchestration (Smart mode).

</td>
</tr>
<tr>
<td width="50%" valign="top">

**Inline Diff Review**
Full split-pane diff view with an inline editor. Review changes and send feedback directly to Claude — without switching windows.

</td>
<td width="50%" valign="top">

**Embedded Terminal**
Full PTY terminal (SwiftTerm) inside each session card. Resume or start sessions without leaving the app. Terminal state persists across transitions.

</td>
</tr>
<tr>
<td width="50%" valign="top">

**Privacy-First Architecture**
Runs entirely on your machine. Reads local session files, communicates over localhost only. No telemetry, no cloud, no tracking.

</td>
<td width="50%" valign="top">

**Workflow Engine**
DAG-based workflow execution with parallel nodes, conditional branching, approval gates, and safe expression evaluation.

</td>
</tr>
</table>

<br />

## Demo

<details>
<summary><b>Full Screen Mode</b></summary>

https://github.com/user-attachments/assets/c616c904-d165-4516-8478-afb810c13606

</details>

<details>
<summary><b>Custom Themes</b></summary>

https://github.com/user-attachments/assets/d4462101-a42b-446c-8491-9a4344539ac6

</details>

<details>
<summary><b>Keyboard Shortcuts</b></summary>

https://github.com/user-attachments/assets/ee453a78-e417-488a-96c7-20732d1d1f60

</details>

<details>
<summary><b>Parallel Execution with Claude Code & Codex</b></summary>

https://github.com/user-attachments/assets/c20c1f3e-745d-4a39-8599-37ad242b3ae6

</details>

<br />

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        macOS Native Client                         │
│                      (Swift / SwiftUI / AppKit)                    │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Hub View │ │ Diff View│ │ Terminal │ │ Cmd      │ │ Settings │ │
│  │ (Cards)  │ │ (Split)  │ │ (PTY)    │ │ Palette  │ │          │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│       └─────────────┴────────────┴─────────────┴────────────┘       │
│                              │                                      │
│                    CLISessionsViewModel                             │
│                    (@MainActor, Combine)                            │
│                              │                                      │
│       ┌──────────────────────┼──────────────────────┐              │
│       │                      │                      │              │
│  SessionFileWatcher    CodexFileWatcher     ThemeFileWatcher       │
│  (kqueue + byte-offset incremental reads)                          │
└──────────┬───────────────────┬───────────────────────────────────────┘
           │                   │
           ▼                   ▼
  ~/.claude/projects/    ~/.codex/sessions/
  {path}/{id}.jsonl      {date}/{id}.jsonl
           │
           │  HTTP + WebSocket (localhost:43210)
           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Local Daemon                               │
│                    (Node.js / Express / WS)                        │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Session  │ │ Workflow │ │ Terminal │ │ Worktree │ │ Runtime  │ │
│  │ Manager  │ │ Engine   │ │ Service  │ │ Service  │ │ Updater  │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ RPC Pool │ │ Search   │ │ Storage  │ │ Stats    │              │
│  │          │ │ Indexer  │ │ (SQLite) │ │ Aggreg.  │              │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

The platform is split into three layers:

| Layer | Tech | Role |
|-------|------|------|
| **Native Client** | Swift 6 / SwiftUI | Real-time UI, file watching, terminal emulation, diff rendering |
| **Local Daemon** | Node.js 22 / Express / WS | Session orchestration, workflow engine, RPC pool, persistence |
| **Protocol** | TypeScript / Zod | Shared type-safe schemas for client-daemon communication |

<br />

## Features

### Session Management
- Real-time monitoring of all Claude Code and Codex sessions
- Session status tracking: Thinking, Executing Tool, Awaiting Approval, Waiting for User, Idle
- Context window usage visualization
- Token counts and cost tracking per session
- Session renaming with SQLite-backed persistence

### Hub Layouts
| Mode | Description |
|------|-------------|
| **Single** | One session at full size with optional side panel (diff, plan, web preview) |
| **List** | Vertical card list grouped by provider |
| **2-Column** | Two-column grid |
| **3-Column** | Three-column grid |

### Multi-Session Launcher
- Launch parallel sessions across Claude Code and Codex
- **Manual mode** — provide prompts directly
- **Smart mode** — AI-planned orchestration that breaks down tasks and assigns to agents

### Git Integration
- Git worktree creation and deletion from the UI
- Launch sessions on new branches
- Inline diff review with split-pane view
- Pending changes preview before accepting tool edits

### Developer Experience
- Command palette (Cmd+K) for quick access
- Web preview with auto-detected dev server launching
- Plan view with markdown and syntax highlighting
- Global search across all session files
- Image and file drag-and-drop attachments

### Customization
- Custom YAML themes with hot-reload
- Built-in themes: Claude, Codex, Bat, Xcode
- Configurable notification sounds for tool approvals
- Menu bar or popover display modes

<br />

## Quick Start

### Prerequisites

- **macOS 14.0+** with Xcode Command Line Tools
- **Node.js >= 22** ([download](https://nodejs.org/))
- **Claude Code CLI** installed and authenticated ([setup](https://docs.anthropic.com/en/docs/claude-code))
- **Codex CLI** (optional, for Codex features) ([setup](https://openai.com/index/introducing-codex/))

### 1. Clone & Install

```bash
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi
npm install
```

### 2. Start the Daemon

```bash
npm run dev
```

The daemon starts on port `43210`. Health check: `GET http://localhost:43210/health`

### 3. Build & Launch the macOS App

```bash
# Build the native app
npm run mac:build

# Open it
npm run mac:open

# Or one-shot: seed demo data + open
npm run mac:demo
```

### 4. Diagnose Your Environment

```bash
npm run dev:doctor
```

<br />

## Scripts Reference

| Script | Description |
|--------|-------------|
| `npm run dev` | Start daemon in development mode |
| `npm run dev:doctor` | Diagnose environment and port availability |
| `npm run typecheck` | Run TypeScript type checking |
| `npm test` | Run unit and contract tests |
| `npm run build` | Build all workspaces |
| `npm run mac:build` | Build the native macOS app |
| `npm run mac:open` | Open the macOS app |
| `npm run mac:demo` | Seed demo data + open app |
| `npm run test:release-gate` | Full release validation (typecheck + test + mac:build + build) |

<br />

## Keyboard Shortcuts

### General

| Shortcut | Action |
|----------|--------|
| **Cmd+K** | Open command palette |
| **Cmd+N** | New session |
| **Cmd+B** | Toggle sidebar |
| **Cmd+,** | Open settings |
| **Cmd+\[** | Previous session |
| **Cmd+\]** | Next session |
| **Escape** | Dismiss maximized card / side panel / sheet |

### Diff View

| Shortcut | Action |
|----------|--------|
| **Return** | Send inline comment to Claude |
| **Cmd+Return** | Add comment to review collection |
| **Shift+Return** | Insert newline in editor |
| **Escape** | Close inline editor or diff view |

### Embedded Terminal

| Shortcut | Action |
|----------|--------|
| **Cmd+C** | Copy selected text |
| **Cmd+V** | Paste |
| **Cmd+A** | Select all |

<br />

## Security Model

AgentPi enforces strict localhost-only security:

- **Token authentication** on all routes except `/health`
  - Header: `x-agentpi-token: <token>`
  - Or: `Authorization: Bearer <token>`
- **CORS whitelist** restricted to `localhost`
- **WebSocket auth** via header or query parameter on `/ws`
- **Audit logging** of all actions to local SQLite
- **No network egress** — all communication stays on `127.0.0.1`

Set your token via the `AGENTPI_DAEMON_TOKEN` environment variable.

<br />

## Custom Themes

Place YAML files in `~/Library/Application Support/AgentPi/themes/`. Changes are picked up instantly via hot-reload.

```yaml
name: My Theme
version: 1
author: Your Name
colors:
  brand:
    primary: "#7C3AED"
    secondary: "#6D28D9"
    tertiary: "#5B21B6"
  backgrounds:
    dark: "#1A1A2E"
    light: "#FFFFFF"
```

<br />

## Project Structure

```
agentpi/
├── apps/
│   └── daemon/                  # Local daemon (Node.js + Express + WebSocket)
│       └── src/
│           ├── app.ts           # HTTP routes + WebSocket server
│           ├── lib/             # Event bus, logger, command runner
│           └── modules/         # Session, workflow, terminal, search, storage, etc.
├── packages/
│   └── protocol/                # Shared Zod schemas (TypeScript)
├── external/
│   └── AgentPi/                 # macOS native client (Swift / SwiftUI)
│       └── app/
│           ├── AgentPi/         # App entry point
│           └── modules/
│               └── AgentPiCore/ # Core Swift package (110+ source files)
│                   └── Sources/AgentPi/
│                       ├── Configuration/   # Provider setup
│                       ├── Design/          # Theme system
│                       ├── Intelligence/    # AI orchestration
│                       ├── Models/          # Core entities
│                       ├── Services/        # 24+ services
│                       ├── UI/              # 46 SwiftUI views
│                       ├── Utils/           # Helpers & extensions
│                       └── ViewModels/      # State management
├── docs/                        # Build, testing, and troubleshooting guides
└── scripts/                     # Build, seed, and diagnostic scripts
```

<br />

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

<br />

## pi-mono Compatibility

AgentPi is compatible with [pi-mono](https://github.com/badlogic/pi-mono) — an open-source AI agent toolkit by [@badlogic](https://github.com/badlogic) that includes a coding agent CLI, unified multi-provider LLM API, TUI/Web UI libraries, and more.

AgentPi can monitor and manage pi-mono coding agent sessions alongside Claude Code and Codex, giving you a single hub for all your AI coding agents regardless of provider.

<br />

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository and create a feature branch
2. Make your changes — keep PRs focused on a single feature or fix
3. Run the release gate to validate: `npm run test:release-gate`
4. Submit a PR describing the motivation, approach, and validation

**Guidelines:**
- One PR per feature or bug fix
- Keep diffs small and reviewable
- AI-generated code is welcome as long as the PR is cohesive
- Unrelated changes bundled together will not be reviewed

See [`external/AgentPi/CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md) for detailed guidelines.

<br />

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS build and branding guide |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | Testing strategy and coverage |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Common issues and fixes |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | Technical architecture deep-dive |

<br />

## License

[MIT](LICENSE) &copy; 2026 James Rochabrun

<br />

<div align="center">
<sub>Built with SwiftUI, Node.js, and a deep belief that your code should stay on your machine.</sub>
</div>
