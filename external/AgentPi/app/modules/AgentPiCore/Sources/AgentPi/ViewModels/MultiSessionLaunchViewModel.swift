//
//  MultiSessionLaunchViewModel.swift
//  AgentPi
//
//  View model for the Session Launcher.
//  Coordinates creating worktrees and starting sessions for Claude, Codex, or both.
//

import AppKit
import Foundation

// MARK: - LaunchMode

public enum LaunchMode: String, CaseIterable, Sendable {
  case manual = "Manual"
  case smart = "Smart"
}

// MARK: - WorkMode

public enum WorkMode: String, CaseIterable, Sendable {
  case local = "Local"
  case worktree = "Worktree"
}

// MARK: - ClaudeMode

public enum ClaudeMode: CaseIterable, Sendable {
  case disabled
  case enabled
  case enabledDangerously

  var next: ClaudeMode {
    switch self {
    case .disabled: return .enabled
    case .enabled: return .enabledDangerously
    case .enabledDangerously: return .disabled
    }
  }

  var isSelected: Bool { self != .disabled }

  var dangerouslySkipPermissions: Bool { self == .enabledDangerously }

  var label: String {
    switch self {
    case .disabled, .enabled: return "Claude"
    case .enabledDangerously: return "Claude Dangerously"
    }
  }
}

// MARK: - SmartPhase

public enum SmartPhase: Equatable {
  case idle
  case planning
  case planReady
  case launching
}

// MARK: - SmartProvider

public enum SmartProvider: String, CaseIterable, Sendable {
  case claude = "Claude"
  case codex = "Codex"
  case pi = "AgentPi"
}

// MARK: - AttachedFile

public struct AttachedFile: Identifiable, Equatable {
  public let id = UUID()
  public let url: URL
  public let isTemporary: Bool

  public var displayName: String { url.lastPathComponent }

  public var icon: String {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "png", "jpg", "jpeg", "gif", "tiff", "webp", "heic": return "photo"
    case "pdf": return "doc.richtext"
    case "txt", "md", "swift", "py", "js", "ts": return "doc.text"
    default: return "doc"
    }
  }

  public var quotedPath: String {
    let path = url.path
    return path.contains(" ") ? "\"\(path)\"" : path
  }
}

// MARK: - MultiSessionLaunchViewModel

@MainActor
@Observable
public final class MultiSessionLaunchViewModel {

  // MARK: - Dependencies

  private let claudeViewModel: CLISessionsViewModel
  private let codexViewModel: CLISessionsViewModel
  private let piViewModel: CLISessionsViewModel
  private let worktreeService: GitWorktreeService
  private let intelligenceViewModel: IntelligenceViewModel?

  // MARK: - Form State

  public var launchMode: LaunchMode = .manual
  public var workMode: WorkMode = .local
  public var claudeMode: ClaudeMode = .disabled
  public var isCodexSelected: Bool = false
  public var isPiSelected: Bool = false
  public var sharedPrompt: String = ""
  public var attachedFiles: [AttachedFile] = []
  public var claudeBranchName: String = ""
  public var codexBranchName: String = ""
  public var piBranchName: String = ""
  public var singleBranchName: String = ""
  public var baseBranch: RemoteBranch?
  public var selectedRepository: SelectedRepository?

  // MARK: - Loaded Data

  public var availableBranches: [RemoteBranch] = []
  public var isLoadingBranches: Bool = false
  public var hasBranchLoadingError: Bool = false
  public var currentBranchName: String = ""
  public var isLoadingCurrentBranch: Bool = false

  // MARK: - Launch State

  public var isLaunching: Bool = false
  public var claudeProgress: WorktreeCreationProgress = .idle
  public var codexProgress: WorktreeCreationProgress = .idle
  public var piProgress: WorktreeCreationProgress = .idle
  public var launchError: String?
  public private(set) var lastLaunchedProviders: [SessionProviderKind] = []
  public private(set) var lastSkippedProviders: [SessionProviderKind] = []
  public private(set) var launchAttemptId: UInt64 = 0

  // MARK: - Smart Mode State

  public var smartPhase: SmartPhase = .idle
  public var smartProvider: SmartProvider = .claude
  public var smartPlanText: String = ""
  public var smartOrchestrationPlan: OrchestrationPlan?

  // MARK: - Callbacks

  public var onLaunchCompleted: (() -> Void)?

  // MARK: - Computed

  public var isClaudeSelected: Bool { claudeMode.isSelected }

  public var selectedProviders: [SessionProviderKind] {
    var providers: [SessionProviderKind] = []
    if isClaudeSelected { providers.append(.claude) }
    if isCodexSelected { providers.append(.codex) }
    if isPiSelected { providers.append(.pi) }
    return providers
  }

  public var hasAnyProviderSelected: Bool {
    isClaudeSelected || isCodexSelected || isPiSelected
  }

  public var isSmartModeAvailable: Bool {
    intelligenceViewModel != nil
  }

  public var isSmartInteractive: Bool {
    smartPhase == .planning || smartPhase == .planReady || smartPhase == .launching
  }

  public var canRetryFailedLaunch: Bool {
    launchError != nil && !isLaunching && launchMode == .manual
  }

  public var canExtendTimeoutAndRetry: Bool {
    canRetryFailedLaunch && (launchError?.contains("GIT_WORKTREE_TIMEOUT") == true)
  }

  public var isValid: Bool {
    let hasRepo = selectedRepository != nil
    switch launchMode {
    case .manual:
      return hasRepo && hasAnyProviderSelected
    case .smart:
      let hasPrompt = !sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return hasRepo && hasPrompt
    }
  }

  public func resolveLaunchProviders() -> (launchable: [SessionProviderKind], missing: [SessionProviderKind]) {
    let availabilities = CLIDetectionService.detectProviderAvailabilities(providers: selectedProviders)
    let launchable = availabilities
      .filter { $0.isLaunchable }
      .map(\.provider)
    let missing = availabilities
      .filter { !$0.isLaunchable }
      .map(\.provider)

    if allowPartialLaunchWhenCLIMissing {
      return (launchable, missing)
    }

    if missing.isEmpty {
      return (launchable, [])
    }

    return ([], missing)
  }

  // MARK: - Init

  public init(
    claudeViewModel: CLISessionsViewModel,
    codexViewModel: CLISessionsViewModel,
    piViewModel: CLISessionsViewModel,
    worktreeService: GitWorktreeService = GitWorktreeService(),
    intelligenceViewModel: IntelligenceViewModel? = nil
  ) {
    self.claudeViewModel = claudeViewModel
    self.codexViewModel = codexViewModel
    self.piViewModel = piViewModel
    self.worktreeService = worktreeService
    self.intelligenceViewModel = intelligenceViewModel
  }

  private func beginLaunchAttempt() -> UInt64 {
    launchAttemptId += 1
    return launchAttemptId
  }

  private func isActiveLaunchAttempt(_ attemptId: UInt64) -> Bool {
    launchAttemptId == attemptId
  }

  private var preserveFormOnFailure: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: AgentPiDefaults.launchPreserveFormOnFailure) == nil {
      return true
    }
    return defaults.bool(forKey: AgentPiDefaults.launchPreserveFormOnFailure)
  }

  private var allowPartialLaunchWhenCLIMissing: Bool {
    let defaults = UserDefaults.standard
    let key = AgentPiDefaults.launchPartialWhenCliMissing
    if defaults.object(forKey: key) == nil {
      return true
    }
    return defaults.bool(forKey: key)
  }

  private func launchErrorCode(for error: Error) -> String {
    if let worktreeError = error as? WorktreeCreationError {
      switch worktreeError {
      case .notAGitRepository: return "GIT_NOT_REPO"
      case .timeout: return "GIT_WORKTREE_TIMEOUT"
      case .directoryAlreadyExists: return "GIT_WORKTREE_DIR_EXISTS"
      case .worktreeAlreadyExists: return "GIT_WORKTREE_EXISTS"
      case .invalidBranchName: return "GIT_INVALID_BRANCH"
      case .fetchFailed: return "GIT_FETCH_FAILED"
      case .gitCommandFailed: return "GIT_COMMAND_FAILED"
      }
    }
    return "LAUNCH_FAILED"
  }

  private func finishManualLaunch(attemptId: UInt64) {
    guard isActiveLaunchAttempt(attemptId) else { return }
    isLaunching = false
    onLaunchCompleted?()
    if launchError == nil {
      reset(clearLaunchOutcome: false)
    } else if !preserveFormOnFailure {
      reset()
    }
  }

  // MARK: - Attachments

  public func addAttachedFile(_ url: URL, isTemporary: Bool = false) {
    guard !attachedFiles.contains(where: { $0.url == url }) else { return }
    attachedFiles.append(AttachedFile(url: url, isTemporary: isTemporary))
  }

  public func removeAttachedFile(_ file: AttachedFile) {
    if file.isTemporary {
      try? FileManager.default.removeItem(at: file.url)
    }
    attachedFiles.removeAll { $0.id == file.id }
  }

  public func clearLaunchError() {
    launchError = nil
  }

  /// Retries the current launch form with optional one-time timeout extension.
  public func retryLaunch(extendWorktreeTimeoutBy seconds: Int? = nil) async {
    guard canRetryFailedLaunch else { return }

    let defaults = UserDefaults.standard
    let timeoutKey = AgentPiDefaults.worktreeTimeoutSeconds
    let hadCustomTimeout = defaults.object(forKey: timeoutKey) != nil
    let previousTimeout = defaults.double(forKey: timeoutKey)

    if let seconds, seconds > 0 {
      let baseline = hadCustomTimeout ? previousTimeout : 30.0
      defaults.set(Int(baseline) + seconds, forKey: timeoutKey)
    }

    await launchSessions()

    if let seconds, seconds > 0 {
      if hadCustomTimeout {
        defaults.set(previousTimeout, forKey: timeoutKey)
      } else {
        defaults.removeObject(forKey: timeoutKey)
      }
    }
  }

  // MARK: - Actions

  /// Opens an NSOpenPanel to select a repository directory.
  /// Uses asyncAfter to schedule NSOpenPanel creation on a future run loop iteration,
  /// avoiding HIRunLoopSemaphore deadlock that occurs during GCD dispatch queue drain.
  public func selectRepository() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      MainActor.assumeIsolated {
        let panel = NSOpenPanel()
        panel.title = L10n.t("launch.repo.select", "Select repository")
        panel.message = L10n.t("launch.repo.select_message", "Choose a git repository")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
          Task {
            await self.selectRepository(at: url.path)
          }
        }
      }
    }
  }

  /// Selects a repository path after validating it as a git repository.
  /// Accepts any subdirectory and normalizes it to the git root.
  public func selectRepository(at path: String) async {
    let validation = await worktreeService.validateRepository(at: path)
    guard validation.isGitRepo, let gitRoot = validation.gitRootPath else {
      launchError = validation.reasonMessage ?? L10n.t("launch.error.invalid_repo", "Selected folder is not a git repository.")
      return
    }

    launchError = nil
    selectedRepository = SelectedRepository(
      path: gitRoot,
      name: URL(fileURLWithPath: gitRoot).lastPathComponent,
      worktrees: [],
      isExpanded: true
    )
    await loadBranches()
  }

  /// Clears the currently selected repository and related branch state.
  public func clearSelectedRepository() {
    selectedRepository = nil
    availableBranches = []
    hasBranchLoadingError = false
    currentBranchName = ""
    baseBranch = nil
    isLoadingBranches = false
    isLoadingCurrentBranch = false
    launchError = nil
  }

  /// Preselects a repository already tracked by either provider.
  /// Returns true when a matching repository was found and selected.
  @discardableResult
  public func preselectRepository(path: String) async -> Bool {
    let combined = claudeViewModel.selectedRepositories
      + codexViewModel.selectedRepositories
      + piViewModel.selectedRepositories
    guard let repository = combined.last(where: { $0.path == path }) else {
      return false
    }

    selectedRepository = repository
    await loadBranches()
    return true
  }

  /// Loads local branches and current branch for the selected repository.
  /// Uses a single `git branch` call to get both, reducing process spawns from 3 to 1-2.
  public func loadBranches() async {
    guard let repo = selectedRepository else { return }
    isLoadingBranches = true
    isLoadingCurrentBranch = true
    hasBranchLoadingError = false

    do {
      let result = try await worktreeService.getLocalBranchesWithCurrent(at: repo.path)
      availableBranches = result.branches
      currentBranchName = result.currentBranchName
      if let current = availableBranches.first(where: { $0.name == currentBranchName }) {
        baseBranch = current
      } else if let first = availableBranches.first {
        baseBranch = first
      }
      launchError = nil
    } catch {
      availableBranches = []
      hasBranchLoadingError = true
      currentBranchName = ""
      launchError = L10n.f(
        "launch.error.branch_load_failed_repo",
        "Unable to load branches for %@. Make sure the selected folder is a git repository.",
        repo.name
      )
    }

    isLoadingBranches = false
    isLoadingCurrentBranch = false
  }

  /// Auto-generates branch names from prompt/attachment context + short UUID suffix.
  /// Falls back to "session" when no context text exists.
  public func autoGenerateBranchNames(for providersOverride: [SessionProviderKind]? = nil) {
    let promptSeed = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let attachmentSeed = attachedFiles
      .prefix(3)
      .map { $0.url.deletingPathExtension().lastPathComponent }
      .joined(separator: "-")
    let rawSeed = !promptSeed.isEmpty ? promptSeed : attachmentSeed

    // Take first few words from available context, sanitize, and add short UUID.
    let words = rawSeed.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .prefix(4)
      .joined(separator: "-")
    let sanitized = GitWorktreeService.sanitizeBranchName(words)
    let suffix = String(UUID().uuidString.prefix(6)).lowercased()
    let base = sanitized.isEmpty ? "session" : sanitized

    let providers = providersOverride ?? selectedProviders
    if providers.count > 1 {
      claudeBranchName = providers.contains(.claude) ? "\(base)-\(suffix)-claude" : ""
      codexBranchName = providers.contains(.codex) ? "\(base)-\(suffix)-codex" : ""
      piBranchName = providers.contains(.pi) ? "\(base)-\(suffix)-pi" : ""
      singleBranchName = ""
    } else {
      singleBranchName = "\(base)-\(suffix)"
      claudeBranchName = ""
      codexBranchName = ""
      piBranchName = ""
    }
  }

  /// Directory name for a given branch name in the selected repository
  public func directoryName(for branchName: String) -> String {
    guard let repo = selectedRepository else { return branchName }
    return GitWorktreeService.worktreeDirectoryName(for: branchName, repoName: repo.name)
  }

  /// Creates worktrees and starts sessions based on the selected providers and work/launch mode
  public func launchSessions() async {
    guard isValid else { return }

    switch launchMode {
    case .manual:
      await launchManualMode()
    case .smart:
      await startSmartPlanning()
    }
  }

  /// Cancels an in-progress smart launch and resets state
  public func cancelSmartLaunch() {
    AppLogger.intelligence.info("Smart launch: cancelled by user")
    intelligenceViewModel?.cancelRequest()
    smartPhase = .idle
    isLaunching = false
    launchError = nil
  }

  // MARK: - Manual Mode

  private func launchManualMode() async {
    guard let repo = selectedRepository else { return }

    let attemptId = beginLaunchAttempt()
    isLaunching = true
    launchError = nil
    claudeProgress = .idle
    codexProgress = .idle
    piProgress = .idle
    lastLaunchedProviders = []
    lastSkippedProviders = []

    let validation = await worktreeService.validateRepository(at: repo.path)
    guard validation.isGitRepo, let gitRoot = validation.gitRootPath else {
      launchError = validation.reasonMessage ?? L10n.t("launch.error.invalid_repo", "Selected folder is not a git repository.")
      finishManualLaunch(attemptId: attemptId)
      return
    }

    if gitRoot != repo.path {
      selectedRepository = SelectedRepository(
        path: gitRoot,
        name: URL(fileURLWithPath: gitRoot).lastPathComponent,
        worktrees: [],
        isExpanded: true
      )
    }

    let providerResolution = resolveLaunchProviders()
    let providers = providerResolution.launchable
    lastLaunchedProviders = providers
    lastSkippedProviders = providerResolution.missing

    guard !providers.isEmpty else {
      launchError = L10n.t(
        "launch.error.no_launchable_agents",
        "No launchable agents. Install at least one CLI and try again."
      )
      finishManualLaunch(attemptId: attemptId)
      return
    }

    let trimmedPrompt = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let attachmentPaths = attachedFiles.map { $0.quotedPath }.joined(separator: " ")
    let initialPrompt: String? = {
      guard !trimmedPrompt.isEmpty else { return nil }
      if attachmentPaths.isEmpty {
        return trimmedPrompt
      }
      return "\(trimmedPrompt) \(attachmentPaths)"
    }()
    let initialInputText: String? =
      trimmedPrompt.isEmpty && !attachmentPaths.isEmpty ? "\(attachmentPaths) " : nil
    let repoPath = gitRoot

    switch workMode {
    case .local:
      await launchLocalSessions(
        providers: providers,
        initialPrompt: initialPrompt,
        initialInputText: initialInputText,
        repoPath: repoPath,
        attemptId: attemptId
      )
    case .worktree:
      if providers.count > 1 {
        let hasAnyBranch = !claudeBranchName.isEmpty || !codexBranchName.isEmpty || !piBranchName.isEmpty
        if !hasAnyBranch {
          autoGenerateBranchNames(for: providers)
        }
      } else if singleBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        autoGenerateBranchNames(for: providers)
      }
      if providers.count > 1 {
        await launchMultipleProviders(
          providers: providers,
          initialPrompt: initialPrompt,
          initialInputText: initialInputText,
          repoPath: repoPath,
          attemptId: attemptId
        )
      } else if let provider = providers.first {
        switch provider {
        case .claude:
          await launchSingleProvider(
            initialPrompt: initialPrompt,
            initialInputText: initialInputText,
            repoPath: repoPath,
            branchName: singleBranchName,
            viewModel: claudeViewModel,
            dangerouslySkipPermissions: claudeMode.dangerouslySkipPermissions,
            progressSetter: { self.claudeProgress = $0 },
            attemptId: attemptId
          )
        case .codex:
          await launchSingleProvider(
            initialPrompt: initialPrompt,
            initialInputText: initialInputText,
            repoPath: repoPath,
            branchName: singleBranchName,
            viewModel: codexViewModel,
            progressSetter: { self.codexProgress = $0 },
            attemptId: attemptId
          )
        case .pi:
          await launchSingleProvider(
            initialPrompt: initialPrompt,
            initialInputText: initialInputText,
            repoPath: repoPath,
            branchName: singleBranchName,
            viewModel: piViewModel,
            progressSetter: { self.piProgress = $0 },
            attemptId: attemptId
          )
        }
      }
    }

    finishManualLaunch(attemptId: attemptId)
  }

  // MARK: - Smart Mode

  /// Phase 1: Send prompt to SDK with plan permission mode and stream a plan.
  private func startSmartPlanning() async {
    guard let repo = selectedRepository,
          let intelligence = intelligenceViewModel else { return }

    let trimmedPrompt = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPrompt.isEmpty else { return }

    AppLogger.intelligence.info("Smart planning: starting for repo \(repo.path)")

    smartPhase = .planning
    isLaunching = true
    launchError = nil

    // Build prompt with attachment paths if any
    let attachmentPaths = attachedFiles.map { $0.quotedPath }.joined(separator: " ")
    let fullPrompt = attachmentPaths.isEmpty ? trimmedPrompt : "\(trimmedPrompt) \(attachmentPaths)"

    // Generate plan via SDK (plan mode, no execution)
    intelligence.generatePlan(prompt: fullPrompt, workingDirectory: repo.path)

    // Poll for completion
    while intelligence.isLoading {
      try? await Task.sleep(for: .milliseconds(200))
    }

    // Check for errors
    if let error = intelligence.errorMessage {
      AppLogger.intelligence.error("Smart planning: error — \(error)")
      launchError = error
      smartPhase = .idle
      isLaunching = false
      return
    }

    // Store completed plan text and parsed orchestration plan
    let rawResponse = intelligence.lastResponse
    let lastMessage = intelligence.lastAssistantMessage
    smartOrchestrationPlan = intelligence.parsedOrchestrationPlan
      ?? WorktreeOrchestrationTool.parseFromText(rawResponse)
      ?? WorktreeOrchestrationTool.parseFromText(lastMessage)
      ?? WorktreeOrchestrationTool.parseJSONFromText(rawResponse)
      ?? WorktreeOrchestrationTool.parseJSONFromText(lastMessage)

    // Use only the final assistant message for display (excludes exploration text)
    smartPlanText = WorktreeOrchestrationTool.stripPlanMarkers(lastMessage)

    // Diagnostic logging
    let planSummary = self.smartOrchestrationPlan.map { "\($0.sessions.count) sessions" } ?? "nil"
    AppLogger.intelligence.info("""
      Smart planning diagnostics:
      - rawResponse length: \(rawResponse.count)
      - lastMessage length: \(lastMessage.count)
      - has XML markers (raw): \(WorktreeOrchestrationTool.containsPlanMarkers(rawResponse))
      - has XML markers (last): \(WorktreeOrchestrationTool.containsPlanMarkers(lastMessage))
      - has JSON keys (raw): \(rawResponse.contains("\"modulePath\""))
      - parsedOrchestrationPlan: \(planSummary)
      """)

    if smartOrchestrationPlan == nil && WorktreeOrchestrationTool.containsPlanMarkers(rawResponse) {
      AppLogger.intelligence.error("Plan markers found but parsing failed. Raw response length: \(rawResponse.count)")
      assertionFailure("Orchestration plan markers present but all parsing attempts failed")
    }

    smartPhase = .planReady
    isLaunching = false
    AppLogger.intelligence.info("Smart planning: plan ready (\(self.smartPlanText.count) chars)")
  }

  /// Phase 2: User approved the plan — create worktrees and start sessions.
  /// If a parsed orchestration plan exists, launches one session per task.
  /// Otherwise falls back to a single session using the full plan text.
  public func approveSmartPlan() async {
    guard let repo = selectedRepository else { return }

    AppLogger.intelligence.info("Smart plan: approved")

    smartPhase = .launching
    isLaunching = true
    launchError = nil

    let viewModel: CLISessionsViewModel = {
      switch smartProvider {
      case .claude: return claudeViewModel
      case .codex: return codexViewModel
      case .pi: return piViewModel
      }
    }()
    let repoPath = repo.path
    let dangerously = smartProvider == .claude ? claudeMode.dangerouslySkipPermissions : false

    viewModel.addRepository(at: repoPath)
    try? await Task.sleep(for: .milliseconds(300))

    if let plan = smartOrchestrationPlan, !plan.sessions.isEmpty {
      // Multi-session launch from parsed orchestration plan
      await launchOrchestrationSessions(
        plan: plan,
        repoPath: repoPath,
        viewModel: viewModel,
        dangerouslySkipPermissions: dangerously
      )
    } else {
      // Fallback: single session with the full plan text (not the original prompt)
      await launchFallbackSession(
        repoPath: repoPath,
        repoName: repo.name,
        viewModel: viewModel,
        dangerouslySkipPermissions: dangerously
      )
    }
  }

  /// Launches one worktree + session per orchestration session.
  private func launchOrchestrationSessions(
    plan: OrchestrationPlan,
    repoPath: String,
    viewModel: CLISessionsViewModel,
    dangerouslySkipPermissions: Bool
  ) async {
    var errors: [String] = []

    for (index, session) in plan.sessions.enumerated() {
      let effectiveBranchName = normalizedBranchName(
        session.branchName,
        fallback: "smart-\(String(UUID().uuidString.prefix(6)).lowercased())-\(index + 1)"
      )
      AppLogger.intelligence.info(
        "Smart plan: creating session \(index + 1)/\(plan.sessions.count) — \(effectiveBranchName)"
      )

      do {
        let dirName = GitWorktreeService.worktreeDirectoryName(
          for: effectiveBranchName, repoName: URL(fileURLWithPath: repoPath).lastPathComponent
        )
        let worktreePath = try await worktreeService.createWorktreeWithNewBranch(
          at: repoPath,
          newBranchName: effectiveBranchName,
          directoryName: dirName,
          startPoint: baseBranch?.displayName
        ) { [weak self] progress in
          Task { @MainActor in
            self?.claudeProgress = progress
          }
        }

        viewModel.refresh()
        try? await Task.sleep(for: .milliseconds(500))

        let worktree = WorktreeBranch(name: effectiveBranchName, path: worktreePath, isWorktree: true)
        viewModel.startNewSessionInHub(
          worktree,
          initialPrompt: session.prompt,
          dangerouslySkipPermissions: dangerouslySkipPermissions
        )
        viewModel.refresh()

        AppLogger.intelligence.info("Smart plan: session launched at \(worktreePath)")

        // Delay between launches to prevent macOS race conditions
        if index < plan.sessions.count - 1 {
          try? await Task.sleep(for: .milliseconds(800))
        }
      } catch {
        let msg = "\(effectiveBranchName): \(error.localizedDescription)"
        AppLogger.intelligence.error("Smart plan: worktree failed — \(msg)")
        errors.append(msg)
      }
    }

    if !errors.isEmpty {
      launchError = "Some sessions failed:\n\(errors.joined(separator: "\n"))"
    }

    isLaunching = false
    onLaunchCompleted?()
    reset()
  }

  /// Fallback: launches a single session with the full plan text as the prompt.
  private func launchFallbackSession(
    repoPath: String,
    repoName: String,
    viewModel: CLISessionsViewModel,
    dangerouslySkipPermissions: Bool
  ) async {
    // Auto-generate branch name from prompt
    let promptSeed = sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = promptSeed.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .prefix(4)
      .joined(separator: "-")
    let sanitized = normalizedBranchName(words, fallback: "smart")
    let suffix = String(UUID().uuidString.prefix(6)).lowercased()
    let branchName = sanitized.isEmpty ? "smart-\(suffix)" : "\(sanitized)-\(suffix)"

    // Use the full plan text as the prompt, not the original user message
    let initialPrompt = smartPlanText.isEmpty ? sharedPrompt : smartPlanText

    do {
      let dirName = GitWorktreeService.worktreeDirectoryName(for: branchName, repoName: repoName)
      let worktreePath = try await worktreeService.createWorktreeWithNewBranch(
        at: repoPath,
        newBranchName: branchName,
        directoryName: dirName,
        startPoint: baseBranch?.displayName
      ) { [weak self] progress in
        Task { @MainActor in
          self?.claudeProgress = progress
        }
      }

      viewModel.refresh()
      try? await Task.sleep(for: .milliseconds(500))

      let worktree = WorktreeBranch(name: branchName, path: worktreePath, isWorktree: true)
      viewModel.startNewSessionInHub(
        worktree,
        initialPrompt: initialPrompt,
        dangerouslySkipPermissions: dangerouslySkipPermissions
      )
      viewModel.refresh()

      AppLogger.intelligence.info("Smart plan: fallback session launched at \(worktreePath)")
      isLaunching = false
      onLaunchCompleted?()
      reset()
    } catch {
      AppLogger.intelligence.error("Smart plan: worktree creation failed — \(error.localizedDescription)")
      launchError = "Worktree creation failed: \(error.localizedDescription)"
      smartPhase = .planReady
      isLaunching = false
    }
  }

  /// Phase 2 (reject): User rejected the plan — go back to idle keeping prompt and repo.
  public func rejectSmartPlan() {
    AppLogger.intelligence.info("Smart plan: rejected by user")
    smartPhase = .idle
    smartPlanText = ""
    smartOrchestrationPlan = nil
  }

  /// Fully resets all form state for a fresh start
  public func reset(clearLaunchOutcome: Bool = true) {
    for file in attachedFiles where file.isTemporary {
      try? FileManager.default.removeItem(at: file.url)
    }
    attachedFiles = []
    sharedPrompt = ""
    claudeBranchName = ""
    codexBranchName = ""
    piBranchName = ""
    singleBranchName = ""
    baseBranch = nil
    selectedRepository = nil
    availableBranches = []
    hasBranchLoadingError = false
    currentBranchName = ""
    launchMode = .manual
    workMode = .local
    claudeMode = .disabled
    isCodexSelected = false
    isPiSelected = false
    claudeProgress = .idle
    codexProgress = .idle
    piProgress = .idle
    launchError = nil
    if clearLaunchOutcome {
      lastLaunchedProviders = []
      lastSkippedProviders = []
    }
    smartPhase = .idle
    smartProvider = .claude
    smartPlanText = ""
    smartOrchestrationPlan = nil
  }

  // MARK: - Private

  /// Starts sessions directly in repo directory without worktree creation
  private func launchLocalSessions(
    providers: [SessionProviderKind],
    initialPrompt: String?,
    initialInputText: String?,
    repoPath: String,
    attemptId: UInt64
  ) async {
    guard isActiveLaunchAttempt(attemptId) else { return }

    for provider in providers {
      let viewModel: CLISessionsViewModel = {
        switch provider {
        case .claude: return claudeViewModel
        case .codex: return codexViewModel
        case .pi: return piViewModel
        }
      }()
      viewModel.addRepository(at: repoPath)
    }

    try? await Task.sleep(for: .milliseconds(300))
    guard isActiveLaunchAttempt(attemptId) else { return }

    let worktree = WorktreeBranch(
      name: currentBranchName.isEmpty ? "main" : currentBranchName,
      path: repoPath,
      isWorktree: false
    )

    if providers.contains(.claude) {
      claudeViewModel.refresh()
      try? await Task.sleep(for: .milliseconds(300))
      guard isActiveLaunchAttempt(attemptId) else { return }
      claudeViewModel.startNewSessionInHub(
        worktree,
        initialPrompt: initialPrompt,
        initialInputText: initialInputText,
        dangerouslySkipPermissions: claudeMode.dangerouslySkipPermissions
      )
    }

    if providers.contains(.codex) {
      try? await Task.sleep(for: .milliseconds(500))
      guard isActiveLaunchAttempt(attemptId) else { return }
      codexViewModel.refresh()
      try? await Task.sleep(for: .milliseconds(300))
      guard isActiveLaunchAttempt(attemptId) else { return }
      codexViewModel.startNewSessionInHub(
        worktree,
        initialPrompt: initialPrompt,
        initialInputText: initialInputText
      )
    }

    if providers.contains(.pi) {
      try? await Task.sleep(for: .milliseconds(500))
      guard isActiveLaunchAttempt(attemptId) else { return }
      piViewModel.refresh()
      try? await Task.sleep(for: .milliseconds(300))
      guard isActiveLaunchAttempt(attemptId) else { return }
      piViewModel.startNewSessionInHub(
        worktree,
        initialPrompt: initialPrompt,
        initialInputText: initialInputText
      )
    }

    claudeViewModel.refresh()
    codexViewModel.refresh()
    piViewModel.refresh()
  }

  private func launchMultipleProviders(
    providers: [SessionProviderKind],
    initialPrompt: String?,
    initialInputText: String?,
    repoPath: String,
    attemptId: UInt64
  ) async {
    guard isActiveLaunchAttempt(attemptId) else { return }
    guard !providers.isEmpty else { return }

    struct ProviderPlan {
      let kind: SessionProviderKind
      let viewModel: CLISessionsViewModel
      let branchName: String
      let dangerouslySkipPermissions: Bool
      let setProgress: @MainActor (WorktreeCreationProgress) -> Void
    }

    let plans: [ProviderPlan] = providers.compactMap { provider in
      switch provider {
      case .claude:
        return ProviderPlan(
          kind: .claude,
          viewModel: claudeViewModel,
          branchName: claudeBranchName,
          dangerouslySkipPermissions: claudeMode.dangerouslySkipPermissions,
          setProgress: { self.claudeProgress = $0 }
        )
      case .codex:
        return ProviderPlan(
          kind: .codex,
          viewModel: codexViewModel,
          branchName: codexBranchName,
          dangerouslySkipPermissions: false,
          setProgress: { self.codexProgress = $0 }
        )
      case .pi:
        return ProviderPlan(
          kind: .pi,
          viewModel: piViewModel,
          branchName: piBranchName,
          dangerouslySkipPermissions: false,
          setProgress: { self.piProgress = $0 }
        )
      }
    }

    // Ensure the repository is added to selected providers first.
    for plan in plans {
      plan.viewModel.addRepository(at: repoPath)
    }
    try? await Task.sleep(for: .milliseconds(300))
    guard isActiveLaunchAttempt(attemptId) else { return }

    var createdWorktrees: [SessionProviderKind: String] = [:]
    var createdBranchNames: [SessionProviderKind: String] = [:]
    var errors: [String] = []

    // Create worktrees one by one so progress per provider is visible and deterministic.
    for plan in plans where !plan.branchName.isEmpty {
      let effectiveBranchName = normalizedBranchName(
        plan.branchName,
        fallback: "\(plan.kind.rawValue.lowercased())-\(String(UUID().uuidString.prefix(6)).lowercased())"
      )
      let operationStart = Date()
      do {
        let dirName = directoryName(for: effectiveBranchName)
        let path = try await worktreeService.createWorktreeWithNewBranch(
          at: repoPath,
          newBranchName: effectiveBranchName,
          directoryName: dirName,
          startPoint: baseBranch?.displayName
        ) { progress in
          Task { @MainActor in
            guard self.isActiveLaunchAttempt(attemptId) else { return }
            plan.setProgress(progress)
          }
        }
        guard isActiveLaunchAttempt(attemptId) else { return }
        createdWorktrees[plan.kind] = path
        createdBranchNames[plan.kind] = effectiveBranchName
      } catch {
        plan.setProgress(.failed(error: error.localizedDescription))
        if isActiveLaunchAttempt(attemptId) {
          let elapsedMs = Int(Date().timeIntervalSince(operationStart) * 1000)
          errors.append(
            "\(plan.kind.rawValue) (\(launchErrorCode(for: error))) repo=\(repoPath) branch=\(effectiveBranchName) elapsedMs=\(elapsedMs) error=\(error.localizedDescription)"
          )
        }
      }
    }

    if !errors.isEmpty {
      launchError = errors.joined(separator: "\n")
    }

    guard !createdWorktrees.isEmpty else { return }

    for plan in plans {
      plan.viewModel.refresh()
    }
    try? await Task.sleep(for: .milliseconds(500))
    guard isActiveLaunchAttempt(attemptId) else { return }

    for plan in plans {
      guard let path = createdWorktrees[plan.kind] else { continue }
      let branchName = createdBranchNames[plan.kind] ?? plan.branchName
      let worktree = WorktreeBranch(name: branchName, path: path, isWorktree: true)
      plan.viewModel.startNewSessionInHub(
        worktree,
        initialPrompt: initialPrompt,
        initialInputText: initialInputText,
        dangerouslySkipPermissions: plan.dangerouslySkipPermissions
      )
      try? await Task.sleep(for: .milliseconds(400))
      guard isActiveLaunchAttempt(attemptId) else { return }
    }

    for plan in plans {
      plan.viewModel.refresh()
    }
  }

  private func launchSingleProvider(
    initialPrompt: String?,
    initialInputText: String?,
    repoPath: String,
    branchName: String,
    viewModel: CLISessionsViewModel,
    dangerouslySkipPermissions: Bool = false,
    progressSetter: @escaping (WorktreeCreationProgress) -> Void,
    attemptId: UInt64
  ) async {
    guard isActiveLaunchAttempt(attemptId) else { return }
    viewModel.addRepository(at: repoPath)
    try? await Task.sleep(for: .milliseconds(300))
    guard isActiveLaunchAttempt(attemptId) else { return }

    let effectiveBranchName = normalizedBranchName(
      branchName,
      fallback: "session-\(String(UUID().uuidString.prefix(6)).lowercased())"
    )

    let operationStart = Date()
    var worktreePath: String?
    do {
      let dirName = directoryName(for: effectiveBranchName)
      worktreePath = try await worktreeService.createWorktreeWithNewBranch(
        at: repoPath,
        newBranchName: effectiveBranchName,
        directoryName: dirName,
        startPoint: baseBranch?.displayName
      ) { progress in
        Task { @MainActor in
          guard self.isActiveLaunchAttempt(attemptId) else { return }
          progressSetter(progress)
        }
      }
      guard isActiveLaunchAttempt(attemptId) else { return }
    } catch {
      if isActiveLaunchAttempt(attemptId) {
        progressSetter(.failed(error: error.localizedDescription))
      }
      if isActiveLaunchAttempt(attemptId) {
        let elapsedMs = Int(Date().timeIntervalSince(operationStart) * 1000)
        launchError = """
        Worktree creation failed (\(launchErrorCode(for: error))).
        repoPath: \(repoPath)
        branch: \(effectiveBranchName)
        elapsedMs: \(elapsedMs)
        error: \(error.localizedDescription)
        """
      }
      return
    }

    guard let path = worktreePath else { return }

    viewModel.refresh()
    try? await Task.sleep(for: .milliseconds(500))
    guard isActiveLaunchAttempt(attemptId) else { return }

    let worktree = WorktreeBranch(name: effectiveBranchName, path: path, isWorktree: true)
    viewModel.startNewSessionInHub(
      worktree,
      initialPrompt: initialPrompt,
      initialInputText: initialInputText,
      dangerouslySkipPermissions: dangerouslySkipPermissions
    )
    viewModel.refresh()
  }

  private func normalizedBranchName(_ raw: String, fallback: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let sanitized = GitWorktreeService.sanitizeBranchName(trimmed)
    if sanitized.isEmpty {
      return GitWorktreeService.sanitizeBranchName(fallback)
    }
    return sanitized
  }
}
