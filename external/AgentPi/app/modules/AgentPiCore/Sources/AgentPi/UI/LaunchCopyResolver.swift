import Foundation

enum LaunchReadinessState {
  case completed
  case missing
  case error
}

enum LaunchReadinessAction {
  case selectRepository
  case selectAgent
  case fixCLI
}

struct LaunchReadinessItem: Identifiable {
  let id: String
  let title: String
  let state: LaunchReadinessState
  let message: String
  let actionTitle: String?
  let action: LaunchReadinessAction?
}

struct LaunchCopyState {
  let launchMode: LaunchMode
  let workMode: WorkMode
  let claudeMode: ClaudeMode
  let isCodexSelected: Bool
  let isPiSelected: Bool
  let hasRepository: Bool
  let hasPromptText: Bool
  let isLoadingBranches: Bool
  let hasBranchLoadError: Bool
  let launchableProviderLabels: [String]
  let missingProviderLabels: [String]

  init(
    launchMode: LaunchMode,
    workMode: WorkMode,
    claudeMode: ClaudeMode,
    isCodexSelected: Bool,
    isPiSelected: Bool,
    hasRepository: Bool = false,
    hasPromptText: Bool = false,
    isLoadingBranches: Bool = false,
    hasBranchLoadError: Bool = false,
    launchableProviderLabels: [String] = [],
    missingProviderLabels: [String] = []
  ) {
    self.launchMode = launchMode
    self.workMode = workMode
    self.claudeMode = claudeMode
    self.isCodexSelected = isCodexSelected
    self.isPiSelected = isPiSelected
    self.hasRepository = hasRepository
    self.hasPromptText = hasPromptText
    self.isLoadingBranches = isLoadingBranches
    self.hasBranchLoadError = hasBranchLoadError
    self.launchableProviderLabels = launchableProviderLabels
    self.missingProviderLabels = missingProviderLabels
  }

  var isClaudeSelected: Bool { claudeMode.isSelected }

  var selectedProviderCount: Int {
    selectedProviderLabels.count
  }

  var selectedProviderLabels: [String] {
    var labels: [String] = []
    if isClaudeSelected { labels.append("Claude") }
    if isCodexSelected { labels.append("Codex") }
    if isPiSelected { labels.append("AgentPi") }
    return labels
  }

  var selectedProviderDisplayText: String {
    selectedProviderLabels.joined(separator: L10n.t("launch.selection.separator", ", "))
  }

  var effectiveLaunchableProviderLabels: [String] {
    if !launchableProviderLabels.isEmpty {
      return launchableProviderLabels
    }
    if missingProviderLabels.isEmpty {
      return selectedProviderLabels
    }
    return selectedProviderLabels.filter { !missingProviderLabels.contains($0) }
  }

  var launchableProviderCount: Int {
    effectiveLaunchableProviderLabels.count
  }

  var missingProviderCount: Int {
    missingProviderLabels.count
  }

  var allSelectedMissing: Bool {
    selectedProviderCount > 0 && launchableProviderCount == 0
  }
}

enum LaunchCopyResolver {
  static func promptPlaceholder(for state: LaunchCopyState) -> String {
    if state.launchMode == .smart {
      return L10n.t("launch.prompt.smart", "Describe what you want to build...")
    } else if state.claudeMode == .enabledDangerously && state.selectedProviderCount == 1 {
      return L10n.t("launch.prompt.dangerous", "Optional: initial prompt (Claude dangerous mode enabled)...")
    } else if state.selectedProviderCount > 1 {
      return L10n.f("launch.prompt.shared_count", "Optional: initial prompt shared by %d sessions...", state.selectedProviderCount)
    } else if state.isClaudeSelected {
      return L10n.t("launch.prompt.claude", "Optional: initial prompt for Claude session...")
    } else if state.isCodexSelected {
      return L10n.t("launch.prompt.codex", "Optional: initial prompt for Codex session...")
    } else if state.isPiSelected {
      return L10n.t("launch.prompt.agentpi", "Optional: initial prompt for AgentPi session...")
    } else {
      return L10n.t("launch.prompt.select_provider", "Select a provider...")
    }
  }

  static func selectionStatusText(for state: LaunchCopyState) -> String {
    if state.selectedProviderLabels.isEmpty {
      return L10n.t("launch.selection.none", "No agents selected")
    }

    return L10n.f(
      "launch.selection.status_format",
      "Selected %d agents: %@",
      state.selectedProviderCount,
      state.selectedProviderDisplayText
    )
  }

  static func sharedPromptBadgeVisible(for state: LaunchCopyState) -> Bool {
    state.selectedProviderCount >= 2
  }

  static func worktreeHintText(for state: LaunchCopyState) -> String? {
    guard state.launchMode == .manual, state.workMode == .worktree, state.selectedProviderCount > 0 else {
      return nil
    }
    return L10n.t("launch.worktree.per_agent_hint", "A separate worktree will be created for each agent")
  }

  static func guidedHintText(for state: LaunchCopyState) -> String? {
    guard state.launchMode == .manual else { return nil }

    if !state.hasRepository {
      return L10n.t("launch.guided.select_repo_first", "Select a repository first, then choose agents.")
    }

    if state.selectedProviderCount == 0 {
      return L10n.t("launch.guided.select_agent_next", "Choose at least one agent to continue.")
    }

    if state.workMode == .worktree && state.hasBranchLoadError {
      return L10n.t("launch.guided.worktree_branch_error", "Resolve branch loading before creating worktrees.")
    }

    if state.allSelectedMissing {
      return L10n.t("launch.guided.fix_cli", "Install missing CLI tools for selected agents.")
    }

    if state.missingProviderCount > 0 {
      return L10n.t("launch.guided.partial_launch", "Missing CLIs will be skipped. You can still launch available agents.")
    }

    return L10n.t("launch.guided.ready_to_launch", "Everything is ready. Add prompt details if needed and launch.")
  }

  static func launchDisabledReason(for state: LaunchCopyState) -> String? {
    if !state.hasRepository {
      return L10n.t("launch.disabled.select_repo", "Please select a repository first")
    }

    if state.launchMode == .manual && state.selectedProviderCount == 0 {
      return L10n.t("launch.disabled.select_agent", "Please select at least 1 agent")
    }

    if state.launchMode == .manual && state.workMode == .worktree && !state.isLoadingBranches && state.hasBranchLoadError {
      return L10n.t("launch.disabled.worktree_branch_load_failed", "Failed to load branches for worktree mode")
    }

    if state.allSelectedMissing {
      return L10n.t("launch.disabled.no_launchable_agents", "No launchable agents. Install at least one selected CLI")
    }

    if state.launchMode == .smart && !state.hasPromptText {
      return L10n.t("launch.disabled.enter_prompt", "Enter a prompt to use Smart mode")
    }

    return nil
  }

  static func readinessItems(for state: LaunchCopyState) -> [LaunchReadinessItem] {
    let repoReady = state.hasRepository
    let repoItem = LaunchReadinessItem(
      id: "repository",
      title: L10n.t("launch.readiness.repo", "Repository"),
      state: repoReady ? .completed : .missing,
      message: repoReady
        ? L10n.t("launch.readiness.repo.ready", "Repository selected")
        : L10n.t("launch.readiness.repo.missing", "Repository is required"),
      actionTitle: repoReady ? nil : L10n.t("launch.action.select_repo", "Select repository"),
      action: repoReady ? nil : .selectRepository
    )

    let agentReady = state.launchMode == .smart || state.selectedProviderCount > 0
    let agentItem = LaunchReadinessItem(
      id: "agent",
      title: L10n.t("launch.readiness.agent", "Agent Selection"),
      state: agentReady ? .completed : .missing,
      message: agentReady
        ? L10n.f("launch.readiness.agent.ready", "%d agent(s) selected", state.selectedProviderCount)
        : L10n.t("launch.readiness.agent.missing", "Select at least one agent"),
      actionTitle: agentReady ? nil : L10n.t("launch.action.select_agent", "Select agent"),
      action: agentReady ? nil : .selectAgent
    )

    let promptItem = LaunchReadinessItem(
      id: "prompt",
      title: L10n.t("launch.readiness.prompt", "Prompt"),
      state: state.hasPromptText ? .completed : .missing,
      message: state.hasPromptText
        ? L10n.t("launch.readiness.prompt.ready", "Prompt is set")
        : L10n.t("launch.readiness.prompt.optional", "Prompt is optional"),
      actionTitle: nil,
      action: nil
    )

    let disabledReason = launchDisabledReason(for: state)
    let readyState: LaunchReadinessState = {
      guard disabledReason != nil else { return .completed }
      if state.hasBranchLoadError || state.allSelectedMissing {
        return .error
      }
      return .missing
    }()

    let readyAction: LaunchReadinessAction? = {
      if !state.hasRepository { return .selectRepository }
      if state.launchMode == .manual && state.selectedProviderCount == 0 { return .selectAgent }
      if state.allSelectedMissing { return .fixCLI }
      return nil
    }()

    let readyItem = LaunchReadinessItem(
      id: "ready",
      title: L10n.t("launch.readiness.ready", "Launch Ready"),
      state: readyState,
      message: disabledReason ?? L10n.t("launch.readiness.ready.ok", "Ready to launch"),
      actionTitle: readyAction == .fixCLI ? L10n.t("launch.action.fix_cli", "Fix CLI setup") : nil,
      action: readyAction == .fixCLI ? .fixCLI : nil
    )

    return [repoItem, agentItem, promptItem, readyItem]
  }

  static func launchButtonTitle(for state: LaunchCopyState, isLaunching: Bool) -> String {
    if state.launchMode == .smart {
      return L10n.t("launch.button.smart", "Launch Smart")
    }

    if isLaunching {
      return state.workMode == .worktree
        ? L10n.t("launch.button.generating_worktrees", "Generating worktrees...")
        : L10n.t("launch.button.launching", "Launching...")
    }

    if state.selectedProviderLabels.isEmpty {
      return L10n.t("launch.button.default", "Launch")
    }

    if state.allSelectedMissing {
      return L10n.t("launch.button.default", "Launch")
    }

    if state.missingProviderCount > 0 && state.launchableProviderCount > 0 {
      return L10n.f(
        "launch.button.launch_with_skip_format",
        "Launch %d Agents (Skip %d)",
        state.launchableProviderCount,
        state.missingProviderCount
      )
    }

    return L10n.f(
      "launch.button.providers_format",
      "Launch %@",
      state.effectiveLaunchableProviderLabels.joined(separator: " + ")
    )
  }
}
