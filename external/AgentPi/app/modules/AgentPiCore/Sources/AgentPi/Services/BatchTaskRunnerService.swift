//
//  BatchTaskRunnerService.swift
//  AgentPi
//
//  Runs non-interactive template commands and streams output into a shared store.
//

import Foundation

public struct BatchTaskExecutionContext: Sendable {
  public var provider: SessionProviderKind
  public var templateId: String
  public var projectPath: String
  public var prompt: String?
  public var cliConfiguration: CLICommandConfiguration

  public init(
    provider: SessionProviderKind,
    templateId: String,
    projectPath: String,
    prompt: String?,
    cliConfiguration: CLICommandConfiguration
  ) {
    self.provider = provider
    self.templateId = templateId
    self.projectPath = projectPath
    self.prompt = prompt
    self.cliConfiguration = cliConfiguration
  }
}

@MainActor
@Observable
public final class BatchTaskRunStore {
  public static let shared = BatchTaskRunStore()

  public private(set) var runs: [BatchTaskRun] = []
  private var contextsByRunId: [String: BatchTaskExecutionContext] = [:]

  public init() {}

  public func appendRun(_ run: BatchTaskRun, context: BatchTaskExecutionContext) {
    runs.insert(run, at: 0)
    contextsByRunId[run.id] = context
  }

  public func appendOutput(runId: String, text: String, isError: Bool) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    runs[index].output.append(BatchTaskOutputChunk(text: text, isError: isError))
  }

  public func markFinished(runId: String, exitCode: Int32) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    runs[index].endedAt = Date()
    runs[index].exitCode = exitCode
    runs[index].status = exitCode == 0 ? .succeeded : .failed
  }

  public func markFailedToStart(runId: String, message: String) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    runs[index].endedAt = Date()
    runs[index].exitCode = -1
    runs[index].status = .failed
    runs[index].output.append(BatchTaskOutputChunk(text: message, isError: true))
  }

  public func context(for runId: String) -> BatchTaskExecutionContext? {
    contextsByRunId[runId]
  }
}

@MainActor
public final class BatchTaskRunnerService {
  public static let shared = BatchTaskRunnerService()

  private let templateService: CommandTemplateService
  public let store: BatchTaskRunStore

  public init(
    templateService: CommandTemplateService,
    store: BatchTaskRunStore
  ) {
    self.templateService = templateService
    self.store = store
  }

  public convenience init() {
    self.init(
      templateService: .shared,
      store: .shared
    )
  }

  @discardableResult
  public func run(context: BatchTaskExecutionContext) -> String? {
    guard let template = templateService.template(by: context.templateId),
      template.enabled
    else {
      return nil
    }
    return run(template: template, context: context)
  }

  @discardableResult
  public func run(
    template: AgentCommandTemplateV1,
    context: BatchTaskExecutionContext
  ) -> String? {
    let resolvedExecutable = templateService.resolvedExecutable(for: template)
    let effectiveConfig = CLICommandConfiguration(
      command: resolvedExecutable,
      additionalPaths: context.cliConfiguration.additionalPaths,
      mode: context.cliConfiguration.mode
    )
    let normalizedConfig = normalizedBatchConfiguration(for: effectiveConfig)
    let didNormalizeHappyRelay = normalizedConfig.command != effectiveConfig.command

    let renderedArgs = normalizedConfig.argumentsForTemplate(
      template,
      context: .init(
        prompt: context.prompt,
        sessionId: nil,
        sessionFilePath: nil,
        projectPath: context.projectPath,
        branch: nil
      )
    )

    let executablePath: String?
    switch context.provider {
    case .claude:
      executablePath = TerminalLauncher.findExecutable(
        command: normalizedConfig.executableName,
        additionalPaths: normalizedConfig.additionalPaths
      )
    case .codex, .pi:
      executablePath = TerminalLauncher.findCodexExecutable(
        command: normalizedConfig.executableName,
        additionalPaths: normalizedConfig.additionalPaths
      )
    }

    let commandLine = ([normalizedConfig.command] + renderedArgs).map(Self.shellEscape).joined(separator: " ")
    let run = BatchTaskRun(
      provider: context.provider,
      templateId: template.id,
      templateName: template.name,
      commandLine: commandLine,
      projectPath: context.projectPath
    )
    store.appendRun(run, context: context)

    if didNormalizeHappyRelay {
      store.appendOutput(
        runId: run.id,
        text: "[AgentPi] '\(effectiveConfig.command)' relay mode does not accept local batch args. Falling back to native '\(normalizedConfig.command)'.\n",
        isError: false
      )
    }

    guard let executablePath else {
      store.markFailedToStart(
        runId: run.id,
        message: "Executable not found: \(normalizedConfig.executableName)"
      )
      return run.id
    }

    Task.detached(priority: .userInitiated) { [runId = run.id] in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executablePath)
      process.arguments = renderedArgs
      process.currentDirectoryURL = URL(fileURLWithPath: context.projectPath)
      process.environment = Self.buildEnvironment(additionalPaths: normalizedConfig.additionalPaths)

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
        Task { @MainActor in
          BatchTaskRunnerService.shared.store.appendOutput(runId: runId, text: text, isError: false)
        }
      }

      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
        Task { @MainActor in
          BatchTaskRunnerService.shared.store.appendOutput(runId: runId, text: text, isError: true)
        }
      }

      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        await MainActor.run {
          BatchTaskRunnerService.shared.store.markFailedToStart(
            runId: runId,
            message: "Failed to start process: \(error.localizedDescription)"
          )
        }
        return
      }

      stdoutPipe.fileHandleForReading.readabilityHandler = nil
      stderrPipe.fileHandleForReading.readabilityHandler = nil
      await MainActor.run {
        BatchTaskRunnerService.shared.store.markFinished(runId: runId, exitCode: process.terminationStatus)
      }
    }

    return run.id
  }

  @discardableResult
  public func rerun(runId: String) -> String? {
    guard let context = store.context(for: runId) else { return nil }
    return run(context: context)
  }

  private nonisolated static func buildEnvironment(additionalPaths: [String]) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let paths = additionalPaths + [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(NSHomeDirectory())/.claude/local",
      "\(NSHomeDirectory())/.pi/agent/bin",
      "\(NSHomeDirectory())/.agentpi/bin",
      "\(NSHomeDirectory())/.agentpi/local",
      "\(NSHomeDirectory())/.codex/local",
      "\(NSHomeDirectory())/.codex/bin",
      "\(NSHomeDirectory())/.local/bin",
      "\(NSHomeDirectory())/.nvm/current/bin",
      "\(NSHomeDirectory())/.nvm/versions/node/v22.16.0/bin",
      "\(NSHomeDirectory())/.nvm/versions/node/v20.11.1/bin",
      "\(NSHomeDirectory())/.nvm/versions/node/v18.19.0/bin"
    ]
    let pathString = paths.joined(separator: ":")
    if let existingPath = environment["PATH"] {
      environment["PATH"] = "\(pathString):\(existingPath)"
    } else {
      environment["PATH"] = pathString
    }
    ProxyEnvironment.apply(to: &environment)
    return environment
  }

  private nonisolated static func shellEscape(_ arg: String) -> String {
    "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private func normalizedBatchConfiguration(for configuration: CLICommandConfiguration) -> CLICommandConfiguration {
    if configuration.isHappyCodexRelayCommand {
      return CLICommandConfiguration(
        command: "codex",
        additionalPaths: configuration.additionalPaths,
        mode: .codex
      )
    }

    if configuration.isHappyPiRelayCommand {
      return CLICommandConfiguration(
        command: "pi",
        additionalPaths: configuration.additionalPaths,
        mode: .pi
      )
    }

    if configuration.isHappyClaudeRelayCommand {
      return CLICommandConfiguration(
        command: "claude",
        additionalPaths: configuration.additionalPaths,
        mode: .claude
      )
    }

    return configuration
  }
}
