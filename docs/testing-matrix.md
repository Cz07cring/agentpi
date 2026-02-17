# AgentPi 功能-测试矩阵（Swift 主线）

## 目标
把 AgentPi 主线（Swift/macOS + daemon）升级为可重复验证、可发布回归。

## 自动化层级
- Unit: 协议、工作流编译器、运行时更新器、会话管理。
- Contract: daemon HTTP/WS 契约、鉴权边界、错误语义。
- Native smoke: AgentPi app 可构建、可启动、会话列表可加载。
- Release gate: `typecheck -> unit/contract -> mac-build -> build`。

## 核心功能映射
| 功能 | API/模块 | 自动化覆盖 |
|---|---|---|
| 健康检查 | `GET /health` | daemon contract test |
| 诊断详情 | `GET /health/details` | daemon contract test |
| 鉴权边界 | HTTP + WS token | daemon contract test |
| Native 启动链路 | `external/AgentPi` (SwiftUI) | `mac:build` + 手动 smoke |
| 会话执行 | `/v1/sessions/*` + `SessionManager` | unit + integration |
| 工作流执行 | `/v1/workflows/*` + `WorkflowEngine` | unit + integration |
| 运行时更新 | `/v1/runtime/update/*` + `PiRuntimeUpdater` | unit |

## 发布门禁
- P0: `npm run typecheck` 全绿。
- P0: `npm test` 全绿。
- P0: `npm run mac:build` 全绿。
- P1: `npm run build` 全绿。

## 待补强（Backlog）
- 增加 XCUITest 覆盖 `New Session -> Prompt -> WaitIdle -> Workflow Run`。
- daemon 并发压力回归（20/50 sessions）纳入 nightly。
- WS 契约补齐 `workflow.run.state`、`approval.*`、`runtime.update.state`。
