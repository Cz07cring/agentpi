import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct LaunchCopyResolverSnapshotTests {
  @Test("zh-Hans: manual 0-provider state snapshot")
  func zhHansManualZeroProviderSnapshot() {
    withLanguage("zh-Hans") {
      let state = LaunchCopyState(
        launchMode: .manual,
        workMode: .local,
        claudeMode: .disabled,
        isCodexSelected: false,
        isPiSelected: false,
        hasRepository: true
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=请选择提供方...
      selection=已选择 0 个 Agent
      badge=false
      worktreeHint=nil
      disabled=请先选择至少 1 个 Agent
      button=启动
      """)
    }
  }

  @Test("en: manual single codex state snapshot")
  func englishManualSingleCodexSnapshot() {
    withLanguage("en") {
      let state = LaunchCopyState(
        launchMode: .manual,
        workMode: .local,
        claudeMode: .disabled,
        isCodexSelected: true,
        isPiSelected: false,
        hasRepository: true
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=Optional: initial prompt for Codex session...
      selection=Selected 1 agents: Codex
      badge=false
      worktreeHint=nil
      disabled=nil
      button=Launch Codex
      """)
    }
  }

  @Test("zh-Hans: manual 3-provider worktree state snapshot")
  func zhHansManualThreeProviderWorktreeSnapshot() {
    withLanguage("zh-Hans") {
      let state = LaunchCopyState(
        launchMode: .manual,
        workMode: .worktree,
        claudeMode: .enabled,
        isCodexSelected: true,
        isPiSelected: true,
        hasRepository: true
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=可选：3 个会话共用的初始提示词...
      selection=已选择 3 个 Agent：Claude、Codex、AgentPi
      badge=true
      worktreeHint=将为每个 Agent 创建独立 worktree
      disabled=nil
      button=启动 Claude + Codex + AgentPi
      """)
    }
  }

  @Test("en: smart mode copy remains stable")
  func englishSmartModeSnapshot() {
    withLanguage("en") {
      let state = LaunchCopyState(
        launchMode: .smart,
        workMode: .local,
        claudeMode: .disabled,
        isCodexSelected: false,
        isPiSelected: false,
        hasRepository: true,
        hasPromptText: true
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=Describe what you want to build...
      selection=No agents selected
      badge=false
      worktreeHint=nil
      disabled=nil
      button=Launch Smart
      """)
    }
  }

  @Test("en: worktree branch load error snapshot")
  func englishWorktreeBranchLoadErrorSnapshot() {
    withLanguage("en") {
      let state = LaunchCopyState(
        launchMode: .manual,
        workMode: .worktree,
        claudeMode: .enabled,
        isCodexSelected: false,
        isPiSelected: false,
        hasRepository: true,
        hasBranchLoadError: true
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=Optional: initial prompt for Claude session...
      selection=Selected 1 agents: Claude
      badge=false
      worktreeHint=A separate worktree will be created for each agent
      disabled=Failed to load branches for worktree mode
      button=Launch Claude
      """)
    }
  }

  @Test("en: missing cli snapshot")
  func englishMissingCLISnapshot() {
    withLanguage("en") {
      let state = LaunchCopyState(
        launchMode: .manual,
        workMode: .local,
        claudeMode: .disabled,
        isCodexSelected: true,
        isPiSelected: false,
        hasRepository: true,
        missingProviderLabels: ["Codex"]
      )

      let snapshot = snapshotText(for: state)
      #expect(snapshot == """
      placeholder=Optional: initial prompt for Codex session...
      selection=Selected 1 agents: Codex
      badge=false
      worktreeHint=nil
      disabled=Install Codex CLI to continue
      button=Launch Codex
      """)
    }
  }
}

private func snapshotText(for state: LaunchCopyState) -> String {
  [
    "placeholder=\(LaunchCopyResolver.promptPlaceholder(for: state))",
    "selection=\(LaunchCopyResolver.selectionStatusText(for: state))",
    "badge=\(LaunchCopyResolver.sharedPromptBadgeVisible(for: state))",
    "worktreeHint=\(LaunchCopyResolver.worktreeHintText(for: state) ?? "nil")",
    "disabled=\(LaunchCopyResolver.launchDisabledReason(for: state) ?? "nil")",
    "button=\(LaunchCopyResolver.launchButtonTitle(for: state, isLaunching: false))",
  ].joined(separator: "\n")
}

@discardableResult
private func withLanguage<T>(_ code: String, body: () throws -> T) rethrows -> T {
  let key = AgentPiDefaults.selectedLanguage
  let defaults = UserDefaults.standard
  let previousValue = defaults.object(forKey: key)

  defaults.set(code, forKey: key)
  defer {
    if let previousValue {
      defaults.set(previousValue, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }

  return try body()
}
