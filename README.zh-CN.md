<div align="center">

**[English](README.md)** | **[中文](README.zh-CN.md)**

# AgentPi

### AI 编程 Agent 的任务控制中心

实时监控和编排 Claude Code、Codex CLI 与 [pi-mono](https://github.com/badlogic/pi-mono) 会话。
macOS 原生客户端 + 本地 Daemon。数据完全不出本机。

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

<!-- TODO: 添加截图 — 例如 ![AgentPi Hub](docs/assets/hub-screenshot.png) -->

</div>

---

## 为什么选择 AgentPi？

同时运行多个 AI 编程 Agent 是一件混乱的事情——搞不清哪个 Agent 在干什么，上下文窗口悄悄用完，工具调用堆积等待审批，费用在不知不觉中飙升。

**AgentPi 给你一个统一的驾驶舱。** 一个界面监控所有活跃会话，内联审查 diff，批准工具调用，并行启动多个 Agent，追踪 token 用量——所有数据完全留在你的本机，绝不外传。

## 功能特性

| | |
|---|---|
| **实时监控** | 通过 kqueue 文件系统监听器实时更新所有活跃会话。状态、token 计数、工具活动、上下文使用量一目了然。 |
| **多供应商** | Claude Code、Codex 和 [pi-mono](https://github.com/badlogic/pi-mono) 会话并排运行。支持手动 prompt 或 AI 智能编排并行启动。 |
| **内联 Diff 审查** | 分栏 diff 视图，内置编辑器。审查代码变更并直接向 Claude 发送反馈。 |
| **内嵌终端** | 每个会话卡片内置完整的 PTY 终端（SwiftTerm）。无需离开 App 即可恢复或启动会话。 |
| **工作流引擎** | 基于 DAG 的工作流执行，支持并行节点、条件分支、审批门控和安全表达式求值。 |
| **Git 集成** | Worktree 管理，基于分支启动会话，内联 diff 审查，待定变更预览。 |
| **开发体验** | 命令面板（Cmd+K），Web 预览，计划视图，全局搜索，拖拽文件附件。 |
| **高度可定制** | YAML 主题热重载，内置主题（Claude / Codex / Bat / Xcode），通知音效，菜单栏或弹窗模式。 |
| **隐私优先** | 完全运行在你的本机。读取本地会话文件，仅通过 localhost 通信。无遥测、无云端、无追踪。 |

## 快速开始

### 前置要求

- **macOS 14.0+** 并安装 Xcode Command Line Tools
- **Node.js >= 22** ([下载](https://nodejs.org/))
- **Claude Code CLI** 已安装并认证 ([设置指南](https://docs.anthropic.com/en/docs/claude-code))
- **Codex CLI**（可选）([设置指南](https://openai.com/index/introducing-codex/))

### 安装与运行

```bash
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi
npm install

# 启动 Daemon（端口 43210）
npm run dev

# 构建并打开 macOS App
npm run mac:build
npm run mac:open

# 或一键完成：注入演示数据 + 打开
npm run mac:demo
```

## 架构

```
┌──────────────────────────────────────────────────────────┐
│                    macOS 原生客户端                       │
│                (Swift / SwiftUI / AppKit)                │
│                                                          │
│  Hub 视图 · Diff 视图 · 终端 · 命令面板 · 设置          │
│                        │                                 │
│              CLISessionsViewModel                        │
│              (@MainActor, Combine)                       │
│                        │                                 │
│  SessionFileWatcher · CodexFileWatcher · ThemeWatcher    │
│  (kqueue + 字节偏移增量读取)                             │
└────────────┬─────────────────────────────────────────────┘
             │
   ~/.claude/projects/{path}/{id}.jsonl
   ~/.codex/sessions/{date}/{id}.jsonl
             │
             │  HTTP + WebSocket (localhost:43210)
             ▼
┌──────────────────────────────────────────────────────────┐
│                       本地 Daemon                        │
│                (Node.js / Express / WS)                  │
│                                                          │
│  会话管理 · 工作流引擎 · 终端服务                        │
│  Worktree 服务 · 运行时更新器 · RPC 进程池               │
│  搜索索引器 · 存储 (SQLite) · 统计聚合器                 │
└──────────────────────────────────────────────────────────┘
```

| 层级 | 技术 | 职责 |
|------|------|------|
| **原生客户端** | Swift 6 / SwiftUI | 实时 UI、文件监听、终端仿真、diff 渲染 |
| **本地 Daemon** | Node.js 22 / Express / WS | 会话编排、工作流引擎、RPC 进程池、持久化 |
| **协议层** | TypeScript / Zod | 客户端 ↔ Daemon 之间的共享类型安全 schema |

## 项目结构

```
agentpi/
├── apps/daemon/               # 本地 Daemon（Node.js + Express + WebSocket）
├── packages/protocol/         # 共享 Zod Schema（TypeScript）
├── external/AgentPi/          # macOS 原生客户端（Swift / SwiftUI）
│   └── app/modules/AgentPiCore/   # 核心 Package（110+ Swift 源文件）
├── docs/                      # 构建、测试、排障文档
└── scripts/                   # 构建、数据注入、诊断脚本
```

## 技术栈

| 组件 | 技术 |
|------|------|
| macOS 客户端 | Swift 6.0, SwiftUI, AppKit, Combine |
| Daemon | Node.js 22, Express 5, WebSocket |
| 协议层 | TypeScript 5.9, Zod 4 |
| 持久化 | SQLite（GRDB.swift + 自定义存储） |
| 文件监听 | kqueue（DispatchSource） |
| 终端 | SwiftTerm（PTY 仿真） |
| Diff 渲染 | PierreDiffsSwift |
| AI 集成 | ClaudeCodeSDK |
| 自动更新 | Sparkle（EdDSA） |
| 测试 | Vitest, XCTest |
| CI/CD | GitHub Actions |

## 脚本参考

| 脚本 | 说明 |
|------|------|
| `npm run dev` | 以开发模式启动 Daemon |
| `npm run dev:doctor` | 诊断本地环境与端口 |
| `npm run typecheck` | TypeScript 类型检查 |
| `npm test` | 单元测试与契约测试 |
| `npm run build` | 构建所有工作区 |
| `npm run mac:build` | 构建 macOS 应用 |
| `npm run mac:open` | 打开 macOS 应用 |
| `npm run mac:demo` | 注入演示数据 + 打开 |
| `npm run test:release-gate` | 完整发布门禁（typecheck + test + mac:build + build） |

## 快捷键

| 快捷键 | 操作 | 快捷键 | 操作 |
|--------|------|--------|------|
| **Cmd+K** | 命令面板 | **Cmd+N** | 新建会话 |
| **Cmd+B** | 切换侧边栏 | **Cmd+,** | 设置 |
| **Cmd+\[** | 上一个会话 | **Cmd+\]** | 下一个会话 |
| **Escape** | 关闭/返回 | **Return** | 发送内联评论（diff） |

## 安全模型

所有通信仅在 `127.0.0.1` 上进行，零网络出口。

- 除 `/health` 外所有路由均需 Token 认证（`x-agentpi-token` header 或 `Bearer` token）
- CORS 白名单仅限 `localhost`
- WebSocket 通过 header 或 query 参数认证
- 所有操作记录到本地 SQLite 审计日志

通过环境变量 `AGENTPI_DAEMON_TOKEN` 设置 token。

## 自定义主题

将 YAML 文件放入 `~/Library/Application Support/AgentPi/themes/`，保存即生效（热重载）。

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

## pi-mono 兼容

AgentPi 兼容 [pi-mono](https://github.com/badlogic/pi-mono) — 由 [@badlogic](https://github.com/badlogic) 开发的开源 AI Agent 工具箱。AgentPi 可以像管理 Claude Code 和 Codex 一样监控 pi-mono 会话——一个中心管理所有 AI 编程 Agent。

## 参与贡献

1. Fork 仓库并创建特性分支
2. 每个 PR 专注一个功能或修复
3. 运行验证：`npm run test:release-gate`
4. 提交 PR，描述动机、方案和测试结果

详见 [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md)。

## 文档

| 文档 | 说明 |
|------|------|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS 构建与品牌化 |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | 测试策略 |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | 常见问题排障 |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | 架构深度解析 |

## 许可证

[MIT](LICENSE) &copy; 2026 ring
