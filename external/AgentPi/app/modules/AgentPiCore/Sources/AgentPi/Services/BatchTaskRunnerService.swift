//
//  BatchTaskRunnerService.swift
//  AgentPi
//
//  Runs non-interactive template commands and streams output into a shared store.
//

import Foundation
import Darwin

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
    var next = runs
    next.insert(run, at: 0)
    runs = next
    contextsByRunId[run.id] = context
  }

  public func appendOutput(runId: String, text: String, isError: Bool) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    var next = runs
    next[index].output.append(BatchTaskOutputChunk(text: text, isError: isError))
    runs = next
  }

  public func markStarted(runId: String, pid: Int32) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    var next = runs
    next[index].pid = pid
    runs = next
  }

  public func markFinished(runId: String, exitCode: Int32) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    guard runs[index].status == .running else { return }
    var next = runs
    next[index].endedAt = Date()
    next[index].exitCode = exitCode
    next[index].status = exitCode == 0 ? .succeeded : .failed
    runs = next
  }

  public func markFailedToStart(runId: String, message: String) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    var next = runs
    next[index].endedAt = Date()
    next[index].exitCode = -1
    next[index].status = .failed
    next[index].output.append(BatchTaskOutputChunk(text: message, isError: true))
    runs = next
  }

  public func context(for runId: String) -> BatchTaskExecutionContext? {
    contextsByRunId[runId]
  }

  public func run(by runId: String) -> BatchTaskRun? {
    runs.first(where: { $0.id == runId })
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
    store.appendOutput(
      runId: run.id,
      text: "[AgentPi] Batch task started. Some templates (like Claude Batch Fast) may output only when finished.\n",
      isError: false
    )

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
      process.standardInput = FileHandle.nullDevice

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        let text = String(decoding: data, as: UTF8.self)
        guard !text.isEmpty else { return }
        Task { @MainActor in
          BatchTaskRunnerService.shared.store.appendOutput(runId: runId, text: text, isError: false)
        }
      }

      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        let text = String(decoding: data, as: UTF8.self)
        guard !text.isEmpty else { return }
        Task { @MainActor in
          BatchTaskRunnerService.shared.store.appendOutput(runId: runId, text: text, isError: true)
        }
      }

      do {
        try process.run()
        await MainActor.run {
          BatchTaskRunnerService.shared.store.markStarted(
            runId: runId,
            pid: process.processIdentifier
          )
        }

        Task.detached(priority: .utility) {
          try? await Task.sleep(for: .seconds(20))
          await MainActor.run {
            guard let current = BatchTaskRunnerService.shared.store.run(by: runId),
              current.status == .running
            else { return }
            BatchTaskRunnerService.shared.store.appendOutput(
              runId: runId,
              text: "[AgentPi] Still running. If it seems stuck, use Stream template or Stop.\n",
              isError: false
            )
          }
        }
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

  @discardableResult
  public func cancel(runId: String) -> Bool {
    guard let run = store.run(by: runId), run.status == .running else { return false }
    guard let pid = run.pid, pid > 0 else {
      store.appendOutput(
        runId: runId,
        text: "[AgentPi] Cannot stop task: missing process id.\n",
        isError: true
      )
      store.markFinished(runId: runId, exitCode: 130)
      return false
    }

    let result = kill(pid, SIGTERM)
    if result == 0 {
      store.appendOutput(
        runId: runId,
        text: "[AgentPi] Stop signal sent.\n",
        isError: false
      )
      store.markFinished(runId: runId, exitCode: 130)
      return true
    }

    store.appendOutput(
      runId: runId,
      text: "[AgentPi] Failed to stop process (pid=\(pid)).\n",
      isError: true
    )
    return false
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
    // Force non-interactive behavior so batch tasks fail fast instead of hanging
    // on git/password prompts that have no TTY in this execution mode.
    environment["CI"] = "1"
    environment["GIT_TERMINAL_PROMPT"] = "0"
    environment["GIT_ASKPASS"] = "/usr/bin/false"
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
