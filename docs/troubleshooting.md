# AgentPi 运行排障手册（Swift 主线）

## 1. 快速诊断

```bash
npm run dev:doctor
```

重点看：
- `xcodebuild` 是否 `found`
- `workspaceExists` 是否 `yes`
- `appBuilt` 是否 `yes`
- `daemonPortListening` 是否符合预期

## 2. 常见症状

### 症状 A：`mac:build` 失败
排查顺序：
1. `xcodebuild -version` 是否可用。
2. 工程路径是否存在：`external/AgentPi/app/AgentPi.xcodeproj`。
3. 本地构建产物目录是否可写：`.build-macos/DerivedData`。

### 症状 B：`mac:open` 没有拉起应用
排查顺序：
1. App 是否已生成：`.build-macos/DerivedData/Build/Products/Debug/AgentPi.app`。
2. 手动拉起验证：
   `open -n /Users/ring/代码/agentpi/.build-macos/DerivedData/Build/Products/Debug/AgentPi.app`

### 症状 C：Daemon 401
排查顺序：
1. 确认请求头携带 `x-agentpi-token`。
2. 检查 `AGENTPI_DAEMON_TOKEN` 是否与 daemon 启动时一致。
3. 调用 `GET /health/details`（带 token）确认鉴权状态。

## 3. 建议运行方式
- 本地后端开发：`npm run dev`
- 原生客户端构建运行：`npm run mac:build && npm run mac:open`
- 回归：`npm run test:release-gate`
