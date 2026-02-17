# AgentPi

AgentPi 是一个本地优先（local-first）的 AI 开发协作平台：  
前端是 macOS 原生 Swift/SwiftUI 客户端，后端是本地 daemon（HTTP + WebSocket），用于会话编排、工作流执行、运行时管理与开发辅助能力。

## Highlights

- macOS 原生客户端：基于 Swift/SwiftUI 定制化主线。
- 本地 daemon：提供会话、工作流、终端、工作区和运行时更新能力。
- 协议统一：`packages/protocol` 用 Zod 定义 schema，前后端共享类型。
- 默认安全模型：本地 token 鉴权 + CORS 白名单（localhost）。
- 开发者友好：内置诊断脚本、测试矩阵、CI 基础配置。

## Architecture

- `external/AgentPi`：macOS 原生客户端（Swift/SwiftUI）
- `apps/daemon`：本地 daemon（Node.js + Express + WS）
- `packages/protocol`：共享协议与 TypeScript 类型
- `docs/`：运行、测试、排障文档

## Quick Start

### 1. Requirements

- Node.js `>=22`
- macOS + Xcode Command Line Tools

### 2. Install

```bash
npm install
```

### 3. Run daemon (dev)

```bash
npm run dev
```

默认监听端口：`43210`  
健康检查：`GET /health`

### 4. Build/open macOS app

```bash
npm run mac:build
npm run mac:seed-demo
npm run mac:open
# one-shot
npm run mac:demo
```

## Core Scripts

- `npm run dev`：启动 daemon（开发模式）
- `npm run dev:doctor`：本地环境与端口诊断
- `npm run typecheck`：类型检查
- `npm test`：单测/契约测试
- `npm run build`：工作区构建
- `npm run test:release-gate`：发布门禁（typecheck + test + mac build + build）

## API Security Model

- `/health` 为匿名可访问。
- 其他 HTTP 路由默认需要 token：
  - Header: `x-agentpi-token: <token>`
  - 或 `Authorization: Bearer <token>`
- WebSocket 路由：`/ws`，同样需要 token（header 或 query）。
- 默认 token 环境变量：`AGENTPI_DAEMON_TOKEN`

## Documents

- macOS 构建与品牌化：`docs/macos-agentpi.md`
- 常见问题与排障：`docs/troubleshooting.md`
- 功能测试矩阵：`docs/testing-matrix.md`

## Open Source Plan

欢迎 Issue / PR，一起把 AgentPi 做成稳定、可扩展的本地 AI 开发基础设施。

建议贡献流程：

1. Fork 仓库并创建特性分支
2. 完成开发并通过 `npm run test:release-gate`
3. 提交 PR，描述变更动机、方案和验证结果

## Publish To GitHub

先在 GitHub 创建一个空仓库：`Cz07cring/agentpi`（不要勾选 Initialize with README）。

然后在本地项目根目录执行：

```bash
git init
git add .
git commit -m "chore: initial open source release"
git branch -M main
git remote add origin git@github.com:Cz07cring/agentpi.git
git push -u origin main
```

如果你希望用 HTTPS remote：

```bash
git remote add origin https://github.com/Cz07cring/agentpi.git
```

## License

当前仓库根目录还没有 `LICENSE` 文件。  
正式开源前，建议补充一个许可证（如 MIT / Apache-2.0）。
