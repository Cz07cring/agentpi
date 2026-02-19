<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/AgentPi-任务控制中心-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PHBhdGggZD0iTTEyIDJ2MTAiLz48cGF0aCBkPSJNMTIgMTJsNiA2Ii8+PC9zdmc+">
  <img alt="AgentPi" src="https://img.shields.io/badge/AgentPi-任务控制中心-7C3AED?style=for-the-badge">
</picture>

# AgentPi

**AI 编程 Agent 的任务控制中心**

实时监控、编排和审查 Claude Code、Codex CLI 与 [pi-mono](https://github.com/badlogic/pi-mono) 会话 — 一切在本地完成。

**[English](README.md)** | **[中文](README.zh-CN.md)**

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

<!-- TODO: 添加截图 — ![AgentPi Hub](docs/assets/hub-screenshot.png) -->

</div>

---

## 为什么选择 AgentPi？

同时运行多个 AI 编程 Agent 非常混乱 — 搞不清哪个 Agent 在干什么，上下文窗口悄悄耗尽，工具调用堆积等待审批，费用在不知不觉中飙升。

**AgentPi 为你提供统一的驾驶舱** — 一个界面监控所有活跃会话，内联审查 diff，批准工具调用，并行启动多个 Agent，追踪 token 用量。所有数据完全留在本机，绝不外传。

## 功能特性

<table>
<tr>
<td width="50%">

**实时监控**
通过 kqueue 文件系统监听器实时更新会话状态。Token 计数、工具活动、上下文使用量一目了然。

**多供应商支持**
Claude Code、Codex 和 pi-mono 会话并排运行。支持手动 prompt 或 AI 智能编排并行启动。

**内联 Diff 审查**
分栏 diff 视图，内置编辑器。审查代码变更并直接向 Claude 发送反馈。

**内嵌终端**
每个会话卡片内置完整 PTY 终端（SwiftTerm）。无需离开 App 即可恢复或启动会话。

</td>
<td width="50%">

**DAG 工作流引擎**
基于有向无环图的执行引擎，支持并行节点、条件分支、审批门控和安全表达式求值。

**智能编排**
通过 ClaudeCodeSDK 实现 AI 驱动的并行任务规划，自动生成并启动多 Agent 会话。

**Git 集成**
Worktree 管理、基于分支启动会话、内联 diff 审查、待定变更预览。

**移动中继**
一键将任务从一个 Provider 会话移交到另一个，保留完整上下文产物。

**开发体验**
命令面板（Cmd+K）、Web 预览、计划视图、全局搜索、拖拽文件附件。

**高度可定制**
YAML 主题热重载。内置主题：Claude / Codex / Bat / Xcode。通知音效，菜单栏或弹窗模式。

</td>
</tr>
</table>

> **隐私优先** — 完全运行在你的本机。读取本地会话文件，仅通过 `localhost` 通信。无遥测、无云端、无追踪。

## 快速开始

### 前置要求

| 要求 | 说明 |
|---|---|
| **macOS 14.0+** | 需安装 Xcode Command Line Tools |
| **Node.js >= 22** | [下载地址](https://nodejs.org/) |
| **Claude Code CLI** | 已安装并完成认证 — [设置指南](https://docs.anthropic.com/en/docs/claude-code) |
| **Codex CLI** *(可选)* | [设置指南](https://openai.com/index/introducing-codex/) |

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi && npm install

# 启动本地 Daemon（端口 43210）
npm run dev

# 构建并启动 macOS App
npm run mac:build && npm run mac:open
```

或使用演示数据快速体验：

```bash
npm run mac:demo
```

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│                      macOS 原生客户端                          │
│                  Swift 6 · SwiftUI · AppKit                   │
│                                                               │
│    Hub  ·  Diff 视图  ·  终端  ·  Cmd+K  ·  设置             │
│                          │                                    │
│                CLISessionsViewModel                           │
│                (@MainActor · Combine)                         │
│                          │                                    │
│    SessionFileWatcher  ·  CodexFileWatcher  ·  ThemeWatcher   │
│              kqueue + 字节偏移增量读取                         │
└──────────────┬───────────────────────────────────────────────┘
               │
               │  读取 ~/.claude/projects/{path}/{id}.jsonl
               │  读取 ~/.codex/sessions/{date}/{id}.jsonl
               │
               │  HTTP + WebSocket · localhost:43210
               ▼
┌──────────────────────────────────────────────────────────────┐
│                         本地 Daemon                            │
│                 Node.js 22 · Express 5 · WS                   │
│                                                               │
│   会话管理  ·  工作流引擎  ·  终端服务                         │
│   Worktree 服务 ·  运行时更新器  ·  RPC 进程池                 │
│   搜索索引器  ·  统计聚合器  ·  SQLite 存储                    │
└──────────────────────────────────────────────────────────────┘
```

| 层级 | 技术 | 职责 |
|---|---|---|
| **原生客户端** | Swift 6 / SwiftUI / AppKit | 实时 UI、文件监听、终端仿真、diff 渲染 |
| **本地 Daemon** | Node.js 22 / Express 5 / WS | 会话编排、工作流引擎、RPC 进程池、持久化 |
| **协议层** | TypeScript 5.9 / Zod 4 | 客户端与 Daemon 之间的共享类型安全 Schema |

## 项目结构

```
agentpi/
├── apps/
│   └── daemon/                    # Node.js 本地服务（Express + WebSocket）
│       └── src/modules/           # 会话、工作流、终端、搜索、统计等模块
├── packages/
│   └── protocol/                  # 共享 Zod Schema 与类型定义（TypeScript）
├── external/
│   └── AgentPi/                   # macOS 原生客户端（Swift / SwiftUI）
│       └── app/modules/AgentPiCore/  # 核心框架（110+ Swift 源文件）
│           └── Sources/AgentPi/
│               ├── Configuration/    # 服务定位器、默认值、环境配置
│               ├── Design/           # 主题系统（YAML 解析、热重载）
│               ├── Models/           # 会话、状态、费用、中继模型
│               ├── Services/         # 文件监听、Git、搜索、终端服务
│               ├── UI/              # 40+ SwiftUI 视图
│               ├── ViewModels/      # @MainActor 视图模型
│               └── Utils/           # 日志、代理、评分工具
├── scripts/                       # 构建、数据注入、诊断脚本
├── docs/                          # 构建、测试、排障文档
└── .github/workflows/             # CI 与发布流水线
```

## 技术栈

| 组件 | 技术 |
|---|---|
| **macOS 客户端** | Swift 6.0, SwiftUI, AppKit, Combine, `@Observable` |
| **并发模型** | Swift actors, `async/await`, `withTaskGroup`, `@MainActor` |
| **Daemon** | Node.js 22, Express 5, WebSocket (`ws`), SQLite (`node:sqlite`) |
| **协议层** | TypeScript 5.9, Zod 4 |
| **持久化** | GRDB.swift（客户端）+ `node:sqlite`（Daemon） |
| **文件监听** | kqueue (DispatchSource)，零轮询，字节偏移增量读取 |
| **终端** | SwiftTerm (PTY 仿真) |
| **Diff 渲染** | PierreDiffsSwift（分栏视图） |
| **语法高亮** | HighlightSwift |
| **Markdown** | swift-markdown-ui |
| **主题解析** | Yams（YAML） |
| **AI 集成** | ClaudeCodeSDK 1.2.4 |
| **自动更新** | Sparkle（EdDSA 签名） |
| **测试** | Vitest（Daemon/协议层）, XCTest（macOS） |
| **CI/CD** | GitHub Actions |
| **Monorepo** | npm workspaces |

## API 概览

Daemon 在 `localhost:43210` 上提供 REST + WebSocket API。

<details>
<summary><strong>会话管理</strong></summary>

| 方法 | 端点 | 说明 |
|---|---|---|
| `GET` | `/v1/sessions` | 列出活跃会话 |
| `POST` | `/v1/sessions` | 创建新会话 |
| `POST` | `/v1/sessions/:id/prompt` | 发送用户 prompt |
| `POST` | `/v1/sessions/:id/steer` | 引导运行中的 Agent |
| `POST` | `/v1/sessions/:id/follow-up` | 追问 |
| `POST` | `/v1/sessions/:id/abort` | 中止运行中的 Agent |
| `POST` | `/v1/sessions/:id/wait-idle` | 阻塞等待会话空闲（最长 60s） |
| `GET` | `/v1/sessions/:id/state` | 获取完整会话状态 |
| `DELETE` | `/v1/sessions/:id` | 关闭会话 |

</details>

<details>
<summary><strong>工作流</strong></summary>

| 方法 | 端点 | 说明 |
|---|---|---|
| `POST` | `/v1/workflows` | 从 DAG 创建工作流 |
| `POST` | `/v1/workflows/:id/run` | 执行工作流 |
| `GET` | `/v1/workflows/runs/:runId` | 获取运行状态 |
| `POST` | `/v1/workflows/:id/validate` | 验证工作流图 |
| `POST` | `/v1/approvals/:id/decision` | 批准或拒绝工具调用 |

</details>

<details>
<summary><strong>其他端点</strong></summary>

| 方法 | 端点 | 说明 |
|---|---|---|
| `POST` | `/v1/terminals` | 启动 PTY 终端 |
| `POST` | `/v1/worktrees` | 创建 Git worktree |
| `GET` | `/v1/search?q=...` | 跨会话全文搜索 |
| `GET` | `/v1/stats/:id` | 会话 Token 与工具统计 |
| `POST` | `/v1/runtime/update/check` | 检查运行时更新 |
| `GET` | `/health` | 健康检查（无需认证） |

</details>

**WebSocket** — `ws://localhost:43210/ws?token=...`
实时事件推送：会话状态、工作流进度、审批请求、终端输出、运行时更新。

## 脚本参考

| 脚本 | 说明 |
|---|---|
| `npm run dev` | 以开发模式启动 Daemon（热重载） |
| `npm run dev:doctor` | 诊断本地环境与端口 |
| `npm run build` | 构建所有工作区 |
| `npm run typecheck` | TypeScript 类型检查 |
| `npm test` | 单元测试与契约测试（Vitest） |
| `npm run mac:build` | 构建 macOS 应用（xcodebuild） |
| `npm run mac:open` | 启动 macOS 应用 |
| `npm run mac:demo` | 注入演示数据并启动 |
| `npm run test:release-gate` | 完整发布门禁（typecheck + test + build） |

## 快捷键

| 快捷键 | 操作 | 快捷键 | 操作 |
|---|---|---|---|
| **Cmd+K** | 命令面板 | **Cmd+N** | 新建会话 |
| **Cmd+B** | 切换侧边栏 | **Cmd+,** | 设置 |
| **Cmd+[** | 上一个会话 | **Cmd+]** | 下一个会话 |
| **Escape** | 关闭 / 返回 | **Return** | 发送内联评论（diff） |

## 安全模型

所有通信仅在 `127.0.0.1` 上进行，零网络出口。

- **Token 认证** — 除 `/health` 外所有路由均需认证，通过 `x-agentpi-token` 或 `Authorization: Bearer`
- **CORS** — 白名单仅限 `localhost` 源
- **WebSocket 认证** — 通过 header 或 query 参数
- **审计日志** — 所有请求记录到本地 SQLite
- **安全求值** — 工作流条件使用沙箱化求值器，不使用 `eval()`

设置 Token：

```bash
export AGENTPI_DAEMON_TOKEN="your-secret-token"
```

## 自定义主题

将 YAML 文件放入 `~/Library/Application Support/AgentPi/Themes/`，保存即生效（热重载）。

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

内置主题：**Claude** | **Codex** | **Bat** | **Xcode**

## pi-mono 兼容

AgentPi 兼容 [pi-mono](https://github.com/badlogic/pi-mono) — 由 [@badlogic](https://github.com/badlogic) 开发的开源 AI Agent 工具箱。在同一个界面中统一监控 pi-mono、Claude Code 和 Codex 会话。

## 参与贡献

1. Fork 仓库并创建特性分支
2. 每个 PR 专注一个功能或修复
3. 提交前运行验证：`npm run test:release-gate`
4. 提交 PR，描述动机、方案和测试结果

详见 [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md)。

## 文档

| 文档 | 说明 |
|---|---|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS 构建与品牌化指南 |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | 测试策略与矩阵 |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | 常见问题与调试 |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | 架构深度解析 |

## 许可证

[MIT](LICENSE) &copy; 2026 ring
