<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://img.shields.io/badge/AgentPi-任务控制中心-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjEwIi8+PHBhdGggZD0iTTEyIDJ2MTAiLz48cGF0aCBkPSJNMTIgMTJsNiA2Ii8+PC9zdmc+">
  <img alt="AgentPi" src="https://img.shields.io/badge/AgentPi-任务控制中心-7C3AED?style=for-the-badge">
</picture>

# AgentPi

### AI 编程 Agent 的任务控制中心

实时监控、编排和审查 **Claude Code**、**Codex CLI** 与 **[pi-mono](https://github.com/badlogic/pi-mono)** 会话 — 一切在本地完成。

**[English](README.md)** | **[中文](README.zh-CN.md)**

[![CI](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml/badge.svg)](https://github.com/Cz07cring/agentpi/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D22-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)

</div>

<br>

> **隐私优先。** 所有数据完全留在本机。无遥测、无云端、无追踪。通信仅限 `localhost`。

---

## 为什么选择 AgentPi？

同时运行多个 AI 编程 Agent 非常混乱 — 搞不清哪个 Agent 在干什么，上下文窗口悄悄耗尽，工具调用堆积等待审批，费用在不知不觉中飙升。

**AgentPi 为你提供统一的驾驶舱** — 一个界面监控所有活跃会话，内联审查 diff，批准工具调用，并行启动多个 Agent，追踪 token 用量。所有数据完全留在本机，绝不外传。

---

## 功能特性

<table>
<tr>
<td width="50%" valign="top">

### 实时监控
通过 kqueue 文件系统监听器实时更新会话状态 — 零轮询，字节偏移增量读取。
Token 计数、工具活动、上下文使用量一目了然。

### 多供应商编排
Claude Code、Codex CLI 和 pi-mono 会话并排运行 — 三者均为一等公民。
支持手动 prompt 或 AI 智能编排，跨 Git Worktree 并行启动。

### 内联 Diff 审查
分栏 diff 视图，语法高亮。
内置编辑器，审查代码变更并直接向 Agent 发送反馈。

### 内嵌终端
每个会话卡片内置完整 PTY 终端（SwiftTerm）。
无需离开 App 即可恢复或启动会话。

### 移动中继 & `happy` CLI
一键将任务在 Provider 间移交（Claude &harr; Codex &harr; Pi）。
生成 JSONL + Markdown 移交产物，保留完整会话上下文。
由 [`happy`](#移动中继--happy-cli-1) CLI 封装驱动，支持智能检测与自动回退。

### 批量任务运行器
通过可配置模板运行非交互式一次性命令。
实时 stdout/stderr 流式输出，停止/重跑控制，耗时追踪。
CI 安全执行，自动 `happy` 中继回退。

</td>
<td width="50%" valign="top">

### 智能编排
通过 ClaudeCodeSDK 实现 AI 驱动的并行任务规划。
三种模式：**并行（Parallel）**、**原型（Prototype）**、**探索（Exploration）**。
Claude 生成结构化编排方案，AgentPi 自动跨 Git Worktree 启动多个会话。

### DAG 工作流引擎
基于有向无环图的执行引擎，支持并行节点、条件分支、审批门控和安全表达式求值。

### 统一命令模板
单一模板系统覆盖所有 Provider 和意图 — `start_session`、`resume_session`、`batch_run`、`mobile_relay`。
支持占位符（`{{prompt}}`、`{{project_path}}`、`{{handoff_jsonl}}`）、自定义可执行文件、拖拽排序、启用/禁用。

### Git 集成
Worktree 管理、基于分支启动会话、待定变更预览、内联 diff 审查。

### 开发体验
命令面板（**Cmd+K**）、Web 预览面板、计划视图、全局全文搜索、拖拽文件附件、开发服务器管理、代理注入、多列布局。

### 主题定制 & 国际化
YAML 主题热重载。内置主题：**Claude**、**Codex**、**Bat**、**Xcode**。
已适配 5 种语言：English、简体中文、日本語、한국어、Tiếng Việt。

### 自动更新
基于 Sparkle 的自动更新，EdDSA 签名验证。
一键本地发布流程，DMG 分发。

</td>
</tr>
</table>

---

## 快速开始

### 前置要求

| 要求 | 说明 |
|:---|:---|
| **macOS 14.0+** | 需安装 Xcode Command Line Tools |
| **Node.js >= 22** | [下载地址](https://nodejs.org/) |
| **Claude Code CLI** | 已安装并完成认证 — [设置指南](https://docs.anthropic.com/en/docs/claude-code) |
| **Codex CLI** *(可选)* | [设置指南](https://openai.com/index/introducing-codex/) |
| **happy CLI** *(可选)* | 启用跨 Provider 移动中继 |

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

---

## 架构

```
┌──────────────────────────────────────────────────────────────────┐
│                      macOS 原生客户端                              │
│                   Swift 6 · SwiftUI · AppKit                     │
│                                                                  │
│    Hub  ·  Diff 视图  ·  终端  ·  Cmd+K  ·  设置                 │
│                           │                                      │
│                 CLISessionsViewModel                             │
│                 (@MainActor · Combine)                           │
│                           │                                      │
│     SessionFileWatcher  ·  CodexFileWatcher  ·  ThemeWatcher     │
│              kqueue + 字节偏移增量读取                              │
└───────────────┬──────────────────────────────────────────────────┘
                │
                │  读取 ~/.claude/projects/{path}/{id}.jsonl
                │  读取 ~/.codex/sessions/{date}/{id}.jsonl
                │
                │  HTTP + WebSocket · localhost:43210
                ▼
┌──────────────────────────────────────────────────────────────────┐
│                         本地 Daemon                               │
│                  Node.js 22 · Express 5 · WS                     │
│                                                                  │
│    会话管理  ·  工作流引擎  ·  终端服务                              │
│    Worktree 服务 ·  运行时更新器  ·  RPC 进程池                     │
│    搜索索引器  ·  统计聚合器  ·  SQLite 存储                        │
│    开发服务器  ·  事件总线                                          │
└──────────────────────────────────────────────────────────────────┘
```

| 层级 | 技术 | 职责 |
|:---|:---|:---|
| **原生客户端** | Swift 6 / SwiftUI / AppKit | 实时 UI、文件监听、终端仿真、diff 渲染 |
| **本地 Daemon** | Node.js 22 / Express 5 / WS | 会话编排、工作流引擎、RPC 进程池、持久化 |
| **协议层** | TypeScript 5.9 / Zod 4 | 客户端与 Daemon 之间的共享类型安全 Schema |

---

## 移动中继 & `happy` CLI

AgentPi 集成 **`happy` CLI 封装**，实现无缝跨 Provider 移交：

```
Claude  → Codex    happy codex --project {{project_path}} --handoff {{handoff_jsonl}}
Claude  → Pi       happy pi --project {{project_path}} --handoff {{handoff_jsonl}}
Codex   → Claude   happy --project {{project_path}} --handoff {{handoff_jsonl}}
Codex   → Pi       happy pi --project {{project_path}} --handoff {{handoff_jsonl}}
Pi      → Claude   happy --project {{project_path}} --handoff {{handoff_jsonl}}
Pi      → Codex    happy codex --project {{project_path}} --handoff {{handoff_jsonl}}
```

**工作流程：**

1. 点击任意活跃会话上的中继按钮
2. AgentPi 捕获会话的 prompt、对话历史、项目路径和 Git 分支
3. 两份移交产物写入 `{project}/.agentpi/mobile-relay/{YYYY-MM-DD}/`：
   - **JSONL** — 机器可读状态（会话 ID、Provider 信息、prompt、时间戳）
   - **Markdown** — 人类可读摘要，包含上下文、diff 和操作指引
4. 目标 Agent 通过 `happy` 启动，完整上下文得以保留

**智能回退：** 当 `happy` 中继命令作为批量模板使用时，AgentPi 自动检测并回退到原生 CLI（`claude`、`codex`、`pi`），确保命令在无外部终端依赖的情况下可靠运行。

---

## 智能编排

AgentPi 通过 **ClaudeCodeSDK** 实现 AI 驱动的并行会话规划。描述你的目标，Claude 自动生成结构化编排方案：

```json
{
  "modulePath": "/path/to/project",
  "sessions": [
    {
      "description": "实现用户认证模块",
      "branchName": "feat/auth-module",
      "sessionType": "parallel",
      "prompt": "实现基于 JWT 的认证..."
    },
    {
      "description": "添加数据库迁移脚本",
      "branchName": "feat/db-migrations",
      "sessionType": "parallel",
      "prompt": "创建迁移脚本..."
    }
  ]
}
```

AgentPi 在独立的 **Git Worktree** 中启动每个会话，跨分支并行运行：

| 模式 | 使用场景 |
|:---|:---|
| **并行（Parallel）** | 同一任务拆分到不同模块或文件 |
| **原型（Prototype）** | 同一目标使用不同实现方案 |
| **探索（Exploration）** | 同时探索相关但独立的功能 |

---

## 命令模板

所有会话启动、批量执行和移动中继命令均由**统一模板系统**（`AgentCommandTemplateV1`）驱动。模板可按 Provider 和意图配置。

### 模板意图

| 意图 | 说明 |
|:---|:---|
| `start_session` | 启动交互式 PTY 会话 |
| `resume_session` | 恢复已有会话 |
| `batch_run` | 一次性非交互式命令 |
| `mobile_relay` | 通过外部终端进行移动移交 |

### 内置模板

| Provider | 模板 | 意图 | 命令 |
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

### 占位符

| 占位符 | 替换为 |
|:---|:---|
| `{{prompt}}` | 用户 prompt 文本 |
| `{{project_path}}` | 项目目录的绝对路径 |
| `{{handoff_jsonl}}` | 生成的 JSONL 移交产物路径 |
| `{{handoff_markdown}}` | 生成的 Markdown 移交产物路径 |
| `{{session_id}}` | 当前会话 ID |
| `{{branch}}` | 当前 Git 分支名 |

在 **设置 → 命令模板** 中创建自定义模板、调整排序、设置各 Provider 默认值。

---

## 批量任务执行器

批量执行器运行由 `batch_run` 模板定义的非交互式命令。与交互式会话不同，批量任务作为无头子进程运行，I/O 通过管道重定向。

- **实时流式输出** — stdout 和 stderr 被捕获并实时显示在批量运行面板中
- **进程管理** — 每个任务追踪 PID；停止发送 SIGTERM，重跑从同一模板重新启动
- **`happy` 自动检测** — 如果 `happy` 中继命令被用作批量模板，AgentPi 会自动回退到原生 CLI 进行本地执行
- **CI 环境** — 批量任务以 `CI=1` 和 `GIT_TERMINAL_PROMPT=0` 环境变量运行，防止交互式提示阻塞执行

---

## 代理支持

AgentPi 支持为 CLI 会话配置代理注入。启用后，代理环境变量（`HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`NO_PROXY`）会自动注入到生成的进程环境中。

在**设置 → 网络**中配置代理，或通过 `ProxyEnvironment` 默认值设置。

---

## 项目结构

```
agentpi/
├── apps/
│   └── daemon/                       # Node.js 本地服务（Express + WebSocket）
│       └── src/modules/              # 会话、工作流、终端、搜索、统计、开发服务器
├── packages/
│   └── protocol/                     # 共享 Zod Schema 与类型定义（TypeScript）
├── external/
│   └── AgentPi/                      # macOS 原生客户端（Swift / SwiftUI）
│       └── app/modules/AgentPiCore/  # 核心框架（120+ Swift 源文件）
│           └── Sources/AgentPi/
│               ├── Configuration/    # 服务定位器、默认值、环境配置
│               ├── Design/           # 主题系统（YAML 解析、热重载）
│               ├── Intelligence/     # 通过 ClaudeCodeSDK 实现智能编排
│               ├── Models/           # 会话、状态、费用、中继、模板模型
│               ├── Services/         # 文件监听、Git、搜索、终端、批量运行器、中继
│               ├── UI/               # 40+ SwiftUI 视图
│               ├── ViewModels/       # @MainActor 视图模型
│               ├── Utils/            # 日志、代理、评分、本地化工具
│               └── Resources/        # 国际化资源（en、zh-Hans、ja、ko、vi）
├── scripts/                          # 构建、数据注入、诊断脚本
├── docs/                             # 构建、测试、排障文档
└── .github/workflows/                # CI/CD 流水线
```

---

## 技术栈

| 组件 | 技术 |
|:---|:---|
| **macOS 客户端** | Swift 6.0, SwiftUI, AppKit, Combine, `@Observable` 宏 |
| **并发模型** | Swift actors, `async/await`, `withTaskGroup`, `@MainActor` |
| **Daemon** | Node.js 22, Express 5, WebSocket (`ws`), SQLite (`node:sqlite`) |
| **协议层** | TypeScript 5.9, Zod 4 |
| **持久化** | GRDB.swift（客户端）+ `node:sqlite`（Daemon） |
| **文件监听** | kqueue (DispatchSource) — 零轮询，字节偏移增量读取 |
| **终端** | SwiftTerm (PTY 仿真) |
| **Diff 渲染** | PierreDiffsSwift（分栏视图 + 内联编辑器） |
| **Markdown** | swift-markdown-ui |
| **语法高亮** | HighlightSwift |
| **主题解析** | Yams（YAML 热重载） |
| **AI 集成** | ClaudeCodeSDK 1.2.4 |
| **CLI 兼容** | `happy` 封装（自动检测与原生回退） |
| **自动更新** | Sparkle（EdDSA 签名） |
| **测试** | Vitest（Daemon/协议层）, XCTest（macOS 客户端） |
| **Monorepo** | npm workspaces |
| **CI/CD** | GitHub Actions |

---

## API 概览

Daemon 在 `localhost:43210` 上提供 REST + WebSocket API。

<details>
<summary><strong>会话管理</strong></summary>

| 方法 | 端点 | 说明 |
|:---|:---|:---|
| `GET` | `/v1/sessions` | 列出活跃会话 |
| `POST` | `/v1/sessions` | 创建新会话 |
| `POST` | `/v1/sessions/:id/prompt` | 发送用户 prompt |
| `POST` | `/v1/sessions/:id/steer` | 引导运行中的 Agent |
| `POST` | `/v1/sessions/:id/follow-up` | 追问 |
| `POST` | `/v1/sessions/:id/abort` | 中止运行中的 Agent |
| `POST` | `/v1/sessions/:id/wait-idle` | 阻塞等待会话空闲（最长 60s） |
| `GET` | `/v1/sessions/:id/state` | 获取完整会话状态 |
| `GET` | `/v1/sessions/:id/runtime-state` | 获取运行时绑定状态 |
| `DELETE` | `/v1/sessions/:id` | 关闭会话 |

</details>

<details>
<summary><strong>工作流与审批</strong></summary>

| 方法 | 端点 | 说明 |
|:---|:---|:---|
| `POST` | `/v1/workflows` | 从 DAG 创建工作流 |
| `POST` | `/v1/workflows/:id/run` | 执行工作流 |
| `GET` | `/v1/workflows/runs/:runId` | 获取运行状态 |
| `POST` | `/v1/workflows/:id/validate` | 验证工作流图 |
| `POST` | `/v1/approvals/:id/decision` | 批准或拒绝工具调用 |

</details>

<details>
<summary><strong>终端、开发服务器与系统</strong></summary>

| 方法 | 端点 | 说明 |
|:---|:---|:---|
| `POST` | `/v1/terminals` | 启动 PTY 终端 |
| `POST` | `/v1/terminals/:id/input` | 发送输入到终端 |
| `DELETE` | `/v1/terminals/:id` | 停止终端 |
| `POST` | `/v1/dev-servers` | 启动开发服务器（npm/pnpm/yarn/bun） |
| `DELETE` | `/v1/dev-servers/:id` | 停止开发服务器 |
| `POST` | `/v1/worktrees` | 创建 Git worktree |
| `DELETE` | `/v1/worktrees/:id` | 删除 Git worktree |
| `GET` | `/v1/search?q=...` | 跨会话全文搜索 |
| `GET` | `/v1/stats/:id` | 会话 Token 与工具统计 |
| `POST` | `/v1/runtime/update/check` | 检查运行时更新 |
| `POST` | `/v1/runtime/update/apply` | 应用运行时更新 |
| `GET` | `/health` | 健康检查（无需认证） |
| `GET` | `/health/details` | 详细健康信息（运行时长、连接数、PID） |

</details>

**WebSocket** — `ws://localhost:43210/ws?token=...`
实时事件推送：会话状态、工作流进度、审批请求、终端输出、运行时更新。

---

## 脚本参考

| 脚本 | 说明 |
|:---|:---|
| `npm run dev` | 以开发模式启动 Daemon（热重载） |
| `npm run dev:doctor` | 诊断本地环境与端口 |
| `npm run build` | 构建所有工作区 |
| `npm run typecheck` | TypeScript 类型检查 |
| `npm test` | 单元测试与契约测试（Vitest） |
| `npm run mac:build` | 构建 macOS 应用（xcodebuild） |
| `npm run mac:open` | 启动 macOS 应用 |
| `npm run mac:demo` | 注入演示数据并启动 |
| `npm run test:release-gate` | 完整发布门禁（typecheck + test + build） |

---

## 快捷键

| 快捷键 | 操作 | 快捷键 | 操作 |
|:---|:---|:---|:---|
| **Cmd+K** | 命令面板 | **Cmd+N** | 新建会话 |
| **Cmd+B** | 切换侧边栏 | **Cmd+,** | 设置 |
| **Cmd+[** | 上一个会话 | **Cmd+]** | 下一个会话 |
| **Escape** | 关闭 / 返回 | **Return** | 发送内联评论（diff 视图） |

---

## 安全模型

所有通信仅在 `127.0.0.1` 上进行，零网络出口。

| 机制 | 说明 |
|:---|:---|
| **Token 认证** | 除 `/health` 外所有路由均需认证，通过 `x-agentpi-token` 或 `Authorization: Bearer` |
| **CORS** | 白名单仅限 `localhost` 源 |
| **WebSocket 认证** | 通过 header 或 query 参数 |
| **审计日志** | 所有请求记录到本地 SQLite |
| **安全求值** | 工作流条件使用沙箱化求值器，不使用 `eval()` |

```bash
export AGENTPI_DAEMON_TOKEN="your-secret-token"
```

---

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

内置主题：**Claude** · **Codex** · **Bat** · **Xcode**

---

## Provider 兼容性

AgentPi 将所有 Provider 视为一等公民：

| Provider | 会话监控 | 批量执行 | 移动中继 | 智能编排 |
|:---|:---:|:---:|:---:|:---:|
| **Claude Code** | &#10003; | &#10003; | &#10003; | &#10003; |
| **Codex CLI** | &#10003; | &#10003; | &#10003; | — |
| **pi-mono** | &#10003; | &#10003; | &#10003; | — |
| **`happy` CLI** | — | &#10003;（回退） | &#10003;（封装） | — |

[pi-mono](https://github.com/badlogic/pi-mono) 是 [@badlogic](https://github.com/badlogic) 开发的开源 AI Agent 工具箱。
`happy` CLI 封装实现无缝跨 Provider 中继，支持智能命令检测与自动原生回退。

---

## 参与贡献

1. Fork 仓库并创建特性分支
2. 每个 PR 专注一个功能或修复
3. 提交前运行验证：`npm run test:release-gate`
4. 提交 PR，描述动机、方案和测试结果

详见 [`CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md)。

---

## 文档

| 文档 | 说明 |
|:---|:---|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS 构建与品牌化指南 |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | 测试策略与矩阵 |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | 常见问题与调试 |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | 架构深度解析 |

---

<div align="center">

[MIT License](LICENSE) &copy; 2026 ring

</div>
