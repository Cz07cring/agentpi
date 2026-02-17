<div align="center">

**[English](README.md)** | **[中文](README.zh-CN.md)**

# AgentPi

### AI 编程 Agent 的任务控制中心

本地优先的 AI 开发协作平台，实时监控和编排 Claude Code、Codex CLI 与 [pi-mono](https://github.com/badlogic/pi-mono) 会话。
macOS 原生客户端 + 本地 Daemon。数据完全不出本机。

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

## 为什么选择 AgentPi？

同时运行多个 AI 编程 Agent 是一件混乱的事情：你搞不清哪个 Agent 在干什么，上下文窗口悄悄用完，工具调用堆积等待审批，费用在不知不觉中飙升。

**AgentPi 给你一个统一的驾驶舱。** 一个界面监控所有 Claude Code、Codex 和 pi-mono 会话，内联审查 diff，批准工具调用，并行启动多个 Agent，追踪 token 用量——所有代码和对话数据完全留在你的本机，绝不外传。

<br />

## 核心亮点

<table>
<tr>
<td width="50%" valign="top">

**实时会话监控**
通过 kqueue 文件系统监听器实时更新所有活跃会话。零轮询。状态、token 计数、工具活动、上下文窗口使用量——一目了然。

</td>
<td width="50%" valign="top">

**多供应商、多会话**
Claude Code、Codex 和 [pi-mono](https://github.com/badlogic/pi-mono) 会话并排运行。支持手动 prompt 或 AI 智能编排（Smart 模式）并行启动多个 Agent。

</td>
</tr>
<tr>
<td width="50%" valign="top">

**内联 Diff 审查**
完整的分栏 diff 视图，内置编辑器。审查代码变更并直接向 Claude 发送反馈——无需切换窗口。

</td>
<td width="50%" valign="top">

**内嵌终端**
每个会话卡片内置完整的 PTY 终端（SwiftTerm）。无需离开 App 即可恢复或启动会话。终端状态跨状态转换保持。

</td>
</tr>
<tr>
<td width="50%" valign="top">

**隐私优先架构**
完全运行在你的本机。读取本地会话文件，仅通过 localhost 通信。无遥测、无云端、无追踪。

</td>
<td width="50%" valign="top">

**工作流引擎**
基于 DAG 的工作流执行，支持并行节点、条件分支、审批门控和安全的表达式求值。

</td>
</tr>
</table>

<br />

## 演示

<details>
<summary><b>全屏模式</b></summary>

https://github.com/user-attachments/assets/c616c904-d165-4516-8478-afb810c13606

</details>

<details>
<summary><b>自定义主题</b></summary>

https://github.com/user-attachments/assets/d4462101-a42b-446c-8491-9a4344539ac6

</details>

<details>
<summary><b>快捷键操作</b></summary>

https://github.com/user-attachments/assets/ee453a78-e417-488a-96c7-20732d1d1f60

</details>

<details>
<summary><b>Claude Code 与 Codex 并行执行</b></summary>

https://github.com/user-attachments/assets/c20c1f3e-745d-4a39-8599-37ad242b3ae6

</details>

<br />

## 架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                      macOS 原生客户端                                │
│                    (Swift / SwiftUI / AppKit)                       │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Hub 视图 │ │ Diff 视图│ │ 终端     │ │ 命令面板 │ │ 设置     │ │
│  │ (卡片)   │ │ (分栏)   │ │ (PTY)    │ │          │ │          │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│       └─────────────┴────────────┴─────────────┴────────────┘       │
│                              │                                      │
│                    CLISessionsViewModel                             │
│                    (@MainActor, Combine)                            │
│                              │                                      │
│       ┌──────────────────────┼──────────────────────┐              │
│       │                      │                      │              │
│  SessionFileWatcher    CodexFileWatcher     ThemeFileWatcher       │
│  (kqueue + 字节偏移增量读取)                                        │
└──────────┬───────────────────┬───────────────────────────────────────┘
           │                   │
           ▼                   ▼
  ~/.claude/projects/    ~/.codex/sessions/
  {path}/{id}.jsonl      {date}/{id}.jsonl
           │
           │  HTTP + WebSocket (localhost:43210)
           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          本地 Daemon                                │
│                    (Node.js / Express / WS)                        │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ 会话管理 │ │ 工作流   │ │ 终端服务 │ │ Worktree │ │ 运行时   │ │
│  │          │ │ 引擎     │ │          │ │ 服务     │ │ 更新器   │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
│  │ RPC 进程 │ │ 搜索     │ │ 存储     │ │ 统计     │              │
│  │ 池       │ │ 索引器   │ │ (SQLite) │ │ 聚合器   │              │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

平台分为三层：

| 层级 | 技术 | 职责 |
|------|------|------|
| **原生客户端** | Swift 6 / SwiftUI | 实时 UI、文件监听、终端仿真、diff 渲染 |
| **本地 Daemon** | Node.js 22 / Express / WS | 会话编排、工作流引擎、RPC 进程池、持久化 |
| **协议层** | TypeScript / Zod | 客户端-Daemon 之间的共享类型安全 schema |

<br />

## 功能特性

### 会话管理
- 实时监控所有 Claude Code 和 Codex 会话
- 会话状态追踪：思考中、执行工具、等待审批、等待用户输入、空闲
- 上下文窗口使用量可视化
- 按会话统计 token 计数和费用
- 支持自定义会话名称（SQLite 持久化）

### Hub 布局

| 模式 | 说明 |
|------|------|
| **单会话** | 全尺寸显示单个会话，可选侧面板（diff、计划、Web 预览） |
| **列表** | 按供应商分组的垂直卡片列表 |
| **两列** | 两列网格 |
| **三列** | 三列网格 |

### 多会话启动器
- 跨 Claude Code 和 Codex 并行启动多个会话
- **手动模式** — 直接提供 prompt
- **Smart 模式** — AI 智能编排，自动拆解任务并分配给各 Agent

### Git 集成
- 在 UI 中创建和删除 Git worktree
- 在新分支上启动会话
- 内联 diff 分栏审查
- 在接受工具编辑前预览待定变更

### 开发体验
- 命令面板（Cmd+K）快速访问
- Web 预览，自动检测项目类型并启动开发服务器
- 计划视图，支持 Markdown 和语法高亮
- 跨所有会话文件的全局搜索
- 拖拽图片和文件附件

### 自定义
- 自定义 YAML 主题，支持热重载
- 内置主题：Claude、Codex、Bat、Xcode
- 可配置的通知音效（工具调用等待审批时提醒）
- 菜单栏或弹出窗口显示模式

<br />

## 快速开始

### 前置要求

- **macOS 14.0+** 并安装 Xcode Command Line Tools
- **Node.js >= 22** ([下载](https://nodejs.org/))
- **Claude Code CLI** 已安装并完成认证 ([设置指南](https://docs.anthropic.com/en/docs/claude-code))
- **Codex CLI**（可选，用于 Codex 功能）([设置指南](https://openai.com/index/introducing-codex/))

### 1. 克隆并安装

```bash
git clone https://github.com/Cz07cring/agentpi.git
cd agentpi
npm install
```

### 2. 启动 Daemon

```bash
npm run dev
```

Daemon 默认监听端口 `43210`。健康检查：`GET http://localhost:43210/health`

### 3. 构建并启动 macOS App

```bash
# 构建原生应用
npm run mac:build

# 打开应用
npm run mac:open

# 或者一键完成：注入演示数据 + 打开应用
npm run mac:demo
```

### 4. 诊断环境

```bash
npm run dev:doctor
```

<br />

## 脚本参考

| 脚本 | 说明 |
|------|------|
| `npm run dev` | 以开发模式启动 Daemon |
| `npm run dev:doctor` | 诊断本地环境与端口可用性 |
| `npm run typecheck` | TypeScript 类型检查 |
| `npm test` | 运行单元测试和契约测试 |
| `npm run build` | 构建所有工作区 |
| `npm run mac:build` | 构建 macOS 原生应用 |
| `npm run mac:open` | 打开 macOS 应用 |
| `npm run mac:demo` | 注入演示数据 + 打开应用 |
| `npm run test:release-gate` | 完整发布门禁（typecheck + test + mac:build + build） |

<br />

## 快捷键

### 通用

| 快捷键 | 操作 |
|--------|------|
| **Cmd+K** | 打开命令面板 |
| **Cmd+N** | 新建会话 |
| **Cmd+B** | 切换侧边栏 |
| **Cmd+,** | 打开设置 |
| **Cmd+\[** | 上一个会话 |
| **Cmd+\]** | 下一个会话 |
| **Escape** | 关闭最大化卡片 / 侧面板 / 弹窗 |

### Diff 视图

| 快捷键 | 操作 |
|--------|------|
| **Return** | 向 Claude 发送内联评论 |
| **Cmd+Return** | 添加评论到审查集合 |
| **Shift+Return** | 在编辑器中插入换行 |
| **Escape** | 关闭内联编辑器或 diff 视图 |

### 内嵌终端

| 快捷键 | 操作 |
|--------|------|
| **Cmd+C** | 复制选中文本 |
| **Cmd+V** | 粘贴 |
| **Cmd+A** | 全选 |

<br />

## 安全模型

AgentPi 执行严格的 localhost-only 安全策略：

- **Token 认证**：除 `/health` 外所有路由均需认证
  - Header: `x-agentpi-token: <token>`
  - 或: `Authorization: Bearer <token>`
- **CORS 白名单**：仅限 `localhost`
- **WebSocket 认证**：通过 header 或 query 参数连接 `/ws`
- **审计日志**：所有操作记录到本地 SQLite
- **零网络出口**：所有通信仅在 `127.0.0.1` 上进行

通过环境变量 `AGENTPI_DAEMON_TOKEN` 设置你的 token。

<br />

## pi-mono 兼容

AgentPi 兼容 [pi-mono](https://github.com/badlogic/pi-mono) — 由 [@badlogic](https://github.com/badlogic) 开发的开源 AI Agent 工具箱，包含编程 Agent CLI、统一的多供应商 LLM API、TUI/Web UI 库、Slack 机器人、vLLM Pod 管理等组件。

AgentPi 可以像管理 Claude Code 和 Codex 一样监控和管理 pi-mono 编程 Agent 会话，为你提供一个统一的中心来管理所有 AI 编程 Agent，不限供应商。

<br />

## 自定义主题

将 YAML 主题文件放入 `~/Library/Application Support/AgentPi/themes/`，保存后立即通过热重载生效。

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

## 项目结构

```
agentpi/
├── apps/
│   └── daemon/                  # 本地 Daemon（Node.js + Express + WebSocket）
│       └── src/
│           ├── app.ts           # HTTP 路由 + WebSocket 服务
│           ├── lib/             # 事件总线、日志、命令执行器
│           └── modules/         # 会话、工作流、终端、搜索、存储等模块
├── packages/
│   └── protocol/                # 共享 Zod Schema（TypeScript）
├── external/
│   └── AgentPi/                 # macOS 原生客户端（Swift / SwiftUI）
│       └── app/
│           ├── AgentPi/         # App 入口
│           └── modules/
│               └── AgentPiCore/ # 核心 Swift Package（110+ 源文件）
│                   └── Sources/AgentPi/
│                       ├── Configuration/   # 供应商配置
│                       ├── Design/          # 主题系统
│                       ├── Intelligence/    # AI 编排
│                       ├── Models/          # 核心实体
│                       ├── Services/        # 24+ 服务
│                       ├── UI/              # 46 个 SwiftUI 视图
│                       ├── Utils/           # 辅助工具和扩展
│                       └── ViewModels/      # 状态管理
├── docs/                        # 构建、测试和排障文档
└── scripts/                     # 构建、数据注入和诊断脚本
```

<br />

## 技术栈

| 组件 | 技术 |
|------|------|
| **macOS 客户端** | Swift 6.0, SwiftUI, AppKit, Combine |
| **Daemon** | Node.js 22, Express 5, WebSocket |
| **协议层** | TypeScript 5.9, Zod 4 |
| **持久化** | SQLite（GRDB.swift + 自定义存储） |
| **文件监听** | kqueue（DispatchSource） |
| **终端** | SwiftTerm（PTY 仿真） |
| **Diff 渲染** | PierreDiffsSwift |
| **AI 集成** | ClaudeCodeSDK |
| **自动更新** | Sparkle（EdDSA） |
| **测试** | Vitest, XCTest |
| **CI/CD** | GitHub Actions |

<br />

## 参与贡献

欢迎参与贡献！以下是参与流程：

1. Fork 仓库并创建特性分支
2. 进行开发——每个 PR 专注一个功能或修复
3. 运行发布门禁验证：`npm run test:release-gate`
4. 提交 PR，描述变更动机、方案和验证结果

**原则：**
- 一个 PR 对应一个功能或修复
- 保持 diff 简洁、易于审查
- 欢迎 AI 生成的代码，但 PR 需保持连贯
- 不接受捆绑不相关变更的 PR

详见 [`external/AgentPi/CONTRIBUTING.md`](external/AgentPi/CONTRIBUTING.md)。

<br />

## 文档

| 文档 | 说明 |
|------|------|
| [`docs/macos-agentpi.md`](docs/macos-agentpi.md) | macOS 构建与品牌化指南 |
| [`docs/testing-matrix.md`](docs/testing-matrix.md) | 测试策略与覆盖率 |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | 常见问题与排障 |
| [`external/AgentPi/CLAUDE.md`](external/AgentPi/CLAUDE.md) | 技术架构深度解析 |

<br />

## 许可证

[MIT](LICENSE) &copy; 2026 James Rochabrun

<br />

<div align="center">
<sub>用 SwiftUI 和 Node.js 构建，坚信你的代码应该留在你的机器上。</sub>
</div>
