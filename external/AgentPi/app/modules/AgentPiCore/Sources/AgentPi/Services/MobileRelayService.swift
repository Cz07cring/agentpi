//
//  MobileRelayService.swift
//  AgentPi
//
//  Launches external mobile relay commands and records handoff tasks.
//

import Foundation

@MainActor
public final class MobileRelayService {
  public static let shared = MobileRelayService()

  private let templateService: CommandTemplateService
  public let store: MobileRelayTaskStore
  private let artifactWriter: MobileRelayArtifactWriter
  private let defaults: UserDefaults

  public init(
    templateService: CommandTemplateService,
    store: MobileRelayTaskStore,
    artifactWriter: MobileRelayArtifactWriter = .init(),
    defaults: UserDefaults = .standard
  ) {
    self.templateService = templateService
    self.store = store
    self.artifactWriter = artifactWriter
    self.defaults = defaults
  }

  public convenience init() {
    self.init(
      templateService: .shared,
      store: .shared
    )
  }

  public func templates(for provider: SessionProviderKind) -> [AgentCommandTemplateV1] {
    templateService.templates(for: provider, intent: .mobileRelay, includeDisabled: false)
  }

  @discardableResult
  public func launch(
    session: CLISession,
    sourceProvider: SessionProviderKind,
    request: MobileRelayLaunchRequest,
    cliConfiguration: CLICommandConfiguration
  ) -> String {
    let initialPrompt = session.lastMessage ?? session.firstMessage
    let createdAt = Date()

    guard let template = resolveTemplate(for: request.targetProvider, preferredTemplateId: request.templateId) else {
      let failed = MobileRelayTask(
        sessionId: session.id,
        sessionShortId: session.shortId,
        sourceProvider: sourceProvider,
        targetProvider: request.targetProvider,
        templateId: request.templateId ?? "",
        templateName: "Missing template",
        commandLine: "",
        projectPath: session.projectPath,
        branch: session.branchName,
        note: request.note,
        initialPrompt: initialPrompt,
        handoffJSONLPath: "",
        handoffMarkdownPath: "",
        status: .failed,
        output: [MobileRelayOutputChunk(
          text: "No enabled mobile relay template for \(request.targetProvider.rawValue). Create one in Settings -> Command Templates.",
          isError: true
        )]
      )
      store.appendTask(failed)
      maybeAutoSwitchPanel()
      return failed.id
    }

    let resolvedExecutable = templateService.resolvedExecutable(for: template)
    let effectiveConfig = CLICommandConfiguration(
      command: resolvedExecutable,
      additionalPaths: cliConfiguration.additionalPaths,
      mode: cliConfiguration.mode
    )

    let paths: MobileRelayArtifactPaths
    do {
      paths = try artifactWriter.createPaths(
        projectPath: session.projectPath,
        sessionShortId: session.shortId,
        at: createdAt
      )
    } catch {
      let failed = MobileRelayTask(
        sessionId: session.id,
        sessionShortId: session.shortId,
        sourceProvider: sourceProvider,
        targetProvider: request.targetProvider,
        templateId: template.id,
        templateName: template.name,
        commandLine: "",
        projectPath: session.projectPath,
        branch: session.branchName,
        note: request.note,
        initialPrompt: initialPrompt,
        handoffJSONLPath: "",
        handoffMarkdownPath: "",
        status: .failed,
        output: [MobileRelayOutputChunk(
          text: "Failed to create handoff artifact directory: \(error.localizedDescription)",
          isError: true
        )]
      )
      store.appendTask(failed)
      maybeAutoSwitchPanel()
      return failed.id
    }

    let renderedArgs = effectiveConfig.argumentsForTemplate(
      template,
      context: .init(
        prompt: initialPrompt,
        sessionId: session.id,
        sessionFilePath: session.sessionFilePath,
        projectPath: session.projectPath,
        branch: session.branchName,
        handoffJSONLPath: paths.jsonlPath,
        handoffMarkdownPath: paths.markdownPath,
        sourceProvider: sourceProvider.stableKey,
        targetProvider: request.targetProvider.stableKey
      )
    )

    let launchTokens = [effectiveConfig.executableName] + renderedArgs
    let commandLine = Self.shellJoin(launchTokens)

    do {
      try artifactWriter.writeArtifacts(
        paths: paths,
        payload: MobileRelayArtifactPayload(
          session: session,
          sourceProvider: sourceProvider,
          targetProvider: request.targetProvider,
          initialPrompt: initialPrompt,
          note: request.note,
          commandLine: commandLine,
          createdAt: createdAt
        )
      )
    } catch {
      let failed = MobileRelayTask(
        sessionId: session.id,
        sessionShortId: session.shortId,
        sourceProvider: sourceProvider,
        targetProvider: request.targetProvider,
        templateId: template.id,
        templateName: template.name,
        commandLine: commandLine,
        projectPath: session.projectPath,
        branch: session.branchName,
        note: request.note,
        initialPrompt: initialPrompt,
        handoffJSONLPath: paths.jsonlPath,
        handoffMarkdownPath: paths.markdownPath,
        status: .failed,
        output: [MobileRelayOutputChunk(
          text: "Failed to write handoff files: \(error.localizedDescription)",
          isError: true
        )]
      )
      store.appendTask(failed)
      maybeAutoSwitchPanel()
      return failed.id
    }

    var task = MobileRelayTask(
      sessionId: session.id,
      sessionShortId: session.shortId,
      sourceProvider: sourceProvider,
      targetProvider: request.targetProvider,
      templateId: template.id,
      templateName: template.name,
      commandLine: commandLine,
      projectPath: session.projectPath,
      branch: session.branchName,
      note: request.note,
      initialPrompt: initialPrompt,
      handoffJSONLPath: paths.jsonlPath,
      handoffMarkdownPath: paths.markdownPath
    )
    task.output.append(MobileRelayOutputChunk(
      text: "Artifacts written:\n- \(paths.jsonlPath)\n- \(paths.markdownPath)\n",
      isError: false
    ))
    store.appendTask(task)
    templateService.setLastUsedTemplate(id: template.id, for: request.targetProvider)

    if let launchError = TerminalLauncher.launchTerminalCommand(commandLine, workingDirectory: session.projectPath) {
      store.appendOutput(
        taskId: task.id,
        text: "Launch failed: \(launchError.localizedDescription)\n",
        isError: true
      )
      store.markFinished(taskId: task.id, status: .failed, exitCode: -1)
    } else {
      store.appendOutput(
        taskId: task.id,
        text: "Relay launched in Terminal and is running. Stop it from Mobile Relay panel or press Ctrl+C in Terminal.\n",
        isError: false
      )
    }

    maybeAutoSwitchPanel()
    return task.id
  }

  @discardableResult
  public func rerun(taskId: String) -> String? {
    guard let existing = store.task(by: taskId) else { return nil }
    let session = CLISession(
      id: existing.sessionId,
      projectPath: existing.projectPath,
      branchName: existing.branch,
      isWorktree: false,
      lastActivityAt: Date(),
      messageCount: 0,
      isActive: false,
      firstMessage: existing.initialPrompt,
      lastMessage: nil,
      slug: nil,
      sessionFilePath: nil
    )
    let request = MobileRelayLaunchRequest(
      targetProvider: existing.targetProvider,
      templateId: existing.templateId,
      note: existing.note
    )
    return launch(
      session: session,
      sourceProvider: existing.sourceProvider,
      request: request,
      cliConfiguration: defaultCLIConfiguration(for: existing.targetProvider)
    )
  }

  @discardableResult
  public func stop(taskId: String) -> Bool {
    guard let existing = store.task(by: taskId) else { return false }
    guard existing.status == .running else { return false }

    let killed = terminateRelayProcess(for: existing)
    if killed {
      store.appendOutput(
        taskId: taskId,
        text: "Stop signal sent. Relay process terminated.\n",
        isError: false
      )
      store.markFinished(taskId: taskId, status: .cancelled, exitCode: 130)
    } else {
      // Process may already be closed manually from Terminal.
      store.appendOutput(
        taskId: taskId,
        text: "No active relay process found. Marked as cancelled.\n",
        isError: false
      )
      store.markFinished(taskId: taskId, status: .cancelled, exitCode: 0)
    }
    return true
  }

  private func resolveTemplate(
    for provider: SessionProviderKind,
    preferredTemplateId: String?
  ) -> AgentCommandTemplateV1? {
    if let preferredTemplateId,
      let preferred = templateService.template(by: preferredTemplateId),
      preferred.provider == provider,
      preferred.intent == .mobileRelay,
      preferred.enabled
    {
      return preferred
    }

    if let lastUsed = templateService.lastUsedTemplate(for: provider, intent: .mobileRelay),
      lastUsed.enabled {
      return lastUsed
    }

    if let defaultTemplate = templateService.defaultTemplate(for: provider, intent: .mobileRelay),
      defaultTemplate.enabled {
      return defaultTemplate
    }

    return templateService.templates(for: provider, intent: .mobileRelay, includeDisabled: false).first
  }

  private func maybeAutoSwitchPanel() {
    let autoSwitch = defaults.object(forKey: AgentPiDefaults.mobileRelayAutoSwitchPanel) as? Bool ?? true
    guard autoSwitch else { return }
    defaults.set("mobile_relay", forKey: AgentPiDefaults.monitorDetailMode)
  }

  private func defaultCLIConfiguration(for provider: SessionProviderKind) -> CLICommandConfiguration {
    switch provider {
    case .claude:
      return CLICommandConfiguration(
        command: defaults.string(forKey: AgentPiDefaults.claudeCommand) ?? "claude",
        mode: .claude
      )
    case .codex:
      return CLICommandConfiguration(
        command: defaults.string(forKey: AgentPiDefaults.codexCommand) ?? "codex",
        mode: .codex
      )
    case .pi:
      return CLICommandConfiguration(
        command: defaults.string(forKey: AgentPiDefaults.piCommand) ?? "pi",
        mode: .pi
      )
    }
  }

  private static func shellJoin(_ tokens: [String]) -> String {
    tokens.map(shellEscape).joined(separator: " ")
  }

  private static func shellEscape(_ token: String) -> String {
    "'\(token.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private func terminateRelayProcess(for task: MobileRelayTask) -> Bool {
    let patternCandidates = [
      "--handoff \(task.handoffJSONLPath)",
      task.handoffJSONLPath,
      task.commandLine
    ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    for pattern in patternCandidates {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
      process.arguments = ["-f", pattern]
      process.environment = ProcessInfo.processInfo.environment

      do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
          return true
        }
      } catch {
        continue
      }
    }
    return false
  }
}
