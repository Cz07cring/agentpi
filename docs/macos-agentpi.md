# AgentPi macOS Native

AgentPi 原生客户端源码位于：

- `/Users/ring/代码/agentpi/external/AgentPi`

## 本次品牌化结果

- 工程名：`AgentPi.xcodeproj`
- Scheme：`AgentPi`
- App 产物：`AgentPi.app`
- Bundle IDs：
  - `com.ring.agentpi`
  - `com.ring.agentpi.tests`
  - `com.ring.agentpi.uitests`
- 用户配置命名空间：`com.ring.agentpi.*`
- 保留 Provider：Claude / Codex / AgentPi

## 构建与运行

```bash
npm run mac:build
npm run mac:seed-demo
npm run mac:open
# or one-shot:
npm run mac:demo
```

## 路径

- Workspace:
  - `/Users/ring/代码/agentpi/external/AgentPi/app/AgentPi.xcodeproj/project.xcworkspace`
- App:
  - `/Users/ring/代码/agentpi/.build-macos/DerivedData/Build/Products/Debug/AgentPi.app`

## 兼容迁移

启动时会自动做以下迁移（幂等）：

- UserDefaults：`com.agenthub.*` -> `com.ring.agentpi.*`
- Application Support：`~/Library/Application Support/AgentHub` -> `~/Library/Application Support/AgentPi`
