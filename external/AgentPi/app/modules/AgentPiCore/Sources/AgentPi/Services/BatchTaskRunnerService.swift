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
  private static let maxRetainedOutputCharacters = 240_000
  private static let trimTargetOutputCharacters = 180_000

  public private(set) var runs: [BatchTaskRun] = []
  private var contextsByRunId: [String: BatchTaskExecutionContext] = [:]
  private var cancelRequestedRunIds: Set<String> = []
  private var cancelledRunIds: Set<String> = []
  private var outputCharacterCountsByRunId: [String: Int] = [:]
  private var truncatedOutputCharacterCountsByRunId: [String: Int] = [:]
  private var truncatedOutputRunIds: Set<String> = []

  public init() {}

  public func appendRun(_ run: BatchTaskRun, context: BatchTaskExecutionContext) {
    removeRunMetadata(run.id)
    var next = runs
    next.insert(run, at: 0)
    runs = next
    contextsByRunId[run.id] = context
    outputCharacterCountsByRunId[run.id] = run.output.reduce(0) { partial, chunk in
      partial + chunk.text.count
    }
  }

  public func appendOutput(runId: String, text: String, isError: Bool) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    // Ignore output for already-finished runs (race between cancel and pipe handlers)
    guard runs[index].status == .running else { return }
    guard !text.isEmpty else { return }

    let (tailText, droppedFromChunk) = tailLimitedText(text, maxCharacters: Self.trimTargetOutputCharacters)
    var next = runs
    if droppedFromChunk > 0 {
      markOutputTruncated(runId: runId, droppedCharacters: droppedFromChunk)
    }
    guard !tailText.isEmpty else {
      runs = next
      return
    }
    next[index].output.append(BatchTaskOutputChunk(text: tailText, isError: isError))
    var totalCharacters = outputCharacterCountsByRunId[runId, default: 0] + tailText.count

    if totalCharacters > Self.maxRetainedOutputCharacters {
      var charactersToDrop = totalCharacters - Self.trimTargetOutputCharacters
      var droppedFromBuffer = 0

      while charactersToDrop > 0, !next[index].output.isEmpty {
        let firstChunkCount = next[index].output[0].text.count
        if firstChunkCount <= charactersToDrop {
          droppedFromBuffer += firstChunkCount
          charactersToDrop -= firstChunkCount
          next[index].output.removeFirst()
          continue
        }

        let trimmed = String(next[index].output[0].text.dropFirst(charactersToDrop))
        droppedFromBuffer += charactersToDrop
        next[index].output[0].text = trimmed
        charactersToDrop = 0
      }

      if droppedFromBuffer > 0 {
        markOutputTruncated(runId: runId, droppedCharacters: droppedFromBuffer)
      }
      totalCharacters = max(0, totalCharacters - droppedFromBuffer)
    }

    outputCharacterCountsByRunId[runId] = totalCharacters
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
    let wasCancelRequested = cancelRequestedRunIds.remove(runId) != nil
    if wasCancelRequested {
      cancelledRunIds.insert(runId)
    } else {
      cancelledRunIds.remove(runId)
    }
    var next = runs
    next[index].endedAt = Date()
    next[index].exitCode = exitCode
    next[index].status = wasCancelRequested ? .failed : (exitCode == 0 ? .succeeded : .failed)
    runs = next
  }

  public func markFailedToStart(runId: String, message: String) {
    guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
    cancelRequestedRunIds.remove(runId)
    cancelledRunIds.remove(runId)
    var next = runs
    next[index].endedAt = Date()
    next[index].exitCode = -1
    next[index].status = .failed
    let (tailMessage, dropped) = tailLimitedText(message, maxCharacters: Self.trimTargetOutputCharacters)
    if dropped > 0 {
      markOutputTruncated(runId: runId, droppedCharacters: dropped)
    }
    if !tailMessage.isEmpty {
      next[index].output.append(BatchTaskOutputChunk(text: tailMessage, isError: true))
      outputCharacterCountsByRunId[runId] = next[index].output.reduce(0) { partial, chunk in
        partial + chunk.text.count
      }
    }
    runs = next
  }

  public func context(for runId: String) -> BatchTaskExecutionContext? {
    contextsByRunId[runId]
  }

  public func run(by runId: String) -> BatchTaskRun? {
    runs.first(where: { $0.id == runId })
  }

  public func removeCompletedRuns() {
    let completedIds = runs.filter { $0.status != .running }.map(\.id)
    guard !completedIds.isEmpty else { return }
    runs.removeAll { $0.status != .running }
    for id in completedIds {
      contextsByRunId.removeValue(forKey: id)
      removeRunMetadata(id)
    }
  }

  @discardableResult
  public func markCancelRequested(runId: String) -> Bool {
    guard let run = run(by: runId), run.status == .running else { return false }
    return cancelRequestedRunIds.insert(runId).inserted
  }

  public func clearCancelRequested(runId: String) {
    cancelRequestedRunIds.remove(runId)
  }

  public func isCancelRequested(runId: String) -> Bool {
    cancelRequestedRunIds.contains(runId)
  }

  public func wasCancelled(runId: String) -> Bool {
    cancelledRunIds.contains(runId)
  }

  public func isOutputTruncated(runId: String) -> Bool {
    truncatedOutputRunIds.contains(runId)
  }

  public func truncatedOutputCharacterCount(runId: String) -> Int {
    truncatedOutputCharacterCountsByRunId[runId, default: 0]
  }

  private func markOutputTruncated(runId: String, droppedCharacters: Int) {
    guard droppedCharacters > 0 else { return }
    truncatedOutputRunIds.insert(runId)
    truncatedOutputCharacterCountsByRunId[runId, default: 0] += droppedCharacters
  }

  private func tailLimitedText(_ text: String, maxCharacters: Int) -> (String, Int) {
    guard maxCharacters > 0 else { return ("", text.count) }
    guard text.count > maxCharacters else { return (text, 0) }
    let dropped = text.count - maxCharacters
    return (String(text.suffix(maxCharacters)), dropped)
  }

  private func removeRunMetadata(_ runId: String) {
    cancelRequestedRunIds.remove(runId)
    cancelledRunIds.remove(runId)
    outputCharacterCountsByRunId.removeValue(forKey: runId)
    truncatedOutputCharacterCountsByRunId.removeValue(forKey: runId)
    truncatedOutputRunIds.remove(runId)
  }
}

@MainActor
public final class BatchTaskRunnerService {
  public static let shared = BatchTaskRunnerService()

  private let templateService: CommandTemplateService
  public let store: BatchTaskRunStore
  private var pendingCancellationRunIds: Set<String> = []

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

    // Capture store/self for use inside Task.detached (avoids hardcoded .shared reference
    // which would break dependency injection and unit testing with non-shared instances).
    let capturedStore = store
    let capturedSelf = self
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
          capturedStore.appendOutput(runId: runId, text: text, isError: false)
        }
      }

      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        let text = String(decoding: data, as: UTF8.self)
        guard !text.isEmpty else { return }
        Task { @MainActor in
          capturedStore.appendOutput(runId: runId, text: text, isError: true)
        }
      }

      do {
        try process.run()
        await MainActor.run {
          capturedStore.markStarted(
            runId: runId,
            pid: process.processIdentifier
          )
          if capturedSelf.pendingCancellationRunIds.remove(runId) != nil {
            _ = capturedSelf.requestStopSignal(
              runId: runId,
              pid: process.processIdentifier,
              queued: true
            )
          }
        }

        Task.detached(priority: .utility) {
          try? await Task.sleep(for: .seconds(20))
          await MainActor.run {
            guard let current = capturedStore.run(by: runId),
              current.status == .running,
              capturedStore.isCancelRequested(runId: runId) == false
            else { return }
            capturedStore.appendOutput(
              runId: runId,
              text: "[AgentPi] Still running. If it seems stuck, use Stream template or Stop.\n",
              isError: false
            )
          }
        }
        process.waitUntilExit()
      } catch {
        await MainActor.run {
          capturedSelf.pendingCancellationRunIds.remove(runId)
          capturedStore.markFailedToStart(
            runId: runId,
            message: "Failed to start process: \(error.localizedDescription)"
          )
        }
        return
      }

      // Detach pipe handlers before marking finished to prevent late output delivery
      stdoutPipe.fileHandleForReading.readabilityHandler = nil
      stderrPipe.fileHandleForReading.readabilityHandler = nil
      await MainActor.run {
        capturedStore.markFinished(runId: runId, exitCode: process.terminationStatus)
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
    if store.isCancelRequested(runId: runId) {
      return true
    }
    guard store.markCancelRequested(runId: runId) else { return false }
    store.appendOutput(
      runId: runId,
      text: "[AgentPi] Stop requested. Waiting for process termination...\n",
      isError: false
    )
    guard let pid = run.pid, pid > 0 else {
      pendingCancellationRunIds.insert(runId)
      store.appendOutput(
        runId: runId,
        text: "[AgentPi] Task is still starting. Stop signal will be sent once the PID is ready.\n",
        isError: false
      )
      return true
    }

    return requestStopSignal(runId: runId, pid: pid, queued: false)
  }

  @discardableResult
  private func requestStopSignal(runId: String, pid: Int32, queued: Bool) -> Bool {
    let stopResult = Self.sendSignal(SIGTERM, to: pid)
    if stopResult.sent {
      store.appendOutput(
        runId: runId,
        text: queued
          ? "[AgentPi] Stop signal sent after process start.\n"
          : "[AgentPi] Stop signal sent.\n",
        isError: false
      )
      scheduleForceStopIfNeeded(runId: runId, pid: pid)
      return true
    }

    if stopResult.errnoCode == ESRCH {
      store.appendOutput(
        runId: runId,
        text: "[AgentPi] Process already exited while sending stop signal.\n",
        isError: false
      )
      return true
    }

    pendingCancellationRunIds.remove(runId)
    store.clearCancelRequested(runId: runId)
    store.appendOutput(
      runId: runId,
      text: "[AgentPi] Failed to stop process (pid=\(pid), errno=\(stopResult.errnoCode)).\n",
      isError: true
    )
    return false
  }

  private func scheduleForceStopIfNeeded(runId: String, pid: Int32) {
    let capturedStore = store
    Task.detached(priority: .utility) {
      try? await Task.sleep(for: .seconds(2))
      let shouldEscalate = await MainActor.run {
        guard let current = capturedStore.run(by: runId),
          current.status == .running,
          current.pid == pid,
          capturedStore.isCancelRequested(runId: runId)
        else { return false }
        return true
      }
      guard shouldEscalate else { return }
      guard Self.isProcessAlive(pid: pid) else { return }

      let forceResult = Self.sendSignal(SIGKILL, to: pid)
      if forceResult.sent {
        await MainActor.run {
          guard let current = capturedStore.run(by: runId),
            current.status == .running,
            current.pid == pid
          else { return }
          capturedStore.appendOutput(
            runId: runId,
            text: "[AgentPi] Process did not stop after SIGTERM. Sent force stop (SIGKILL).\n",
            isError: false
          )
        }

        try? await Task.sleep(for: .milliseconds(700))
        guard Self.isProcessAlive(pid: pid) else { return }
        await MainActor.run {
          guard let current = capturedStore.run(by: runId),
            current.status == .running,
            current.pid == pid
          else { return }
          capturedStore.appendOutput(
            runId: runId,
            text: "[AgentPi] Process is still alive after SIGKILL. It may have spawned unmanaged child processes.\n",
            isError: true
          )
        }
        return
      }

      if forceResult.errnoCode == ESRCH {
        await MainActor.run {
          capturedStore.appendOutput(
            runId: runId,
            text: "[AgentPi] Process exited while escalating stop.\n",
            isError: false
          )
        }
        return
      }

      await MainActor.run {
        guard let current = capturedStore.run(by: runId),
          current.status == .running,
          current.pid == pid
        else { return }
        capturedStore.appendOutput(
          runId: runId,
          text: "[AgentPi] Failed to force stop process (pid=\(pid), errno=\(forceResult.errnoCode)).\n",
          isError: true
        )
        capturedStore.clearCancelRequested(runId: runId)
      }
    }
  }

  private nonisolated static func sendSignal(_ signal: Int32, to pid: Int32) -> (sent: Bool, errnoCode: Int32) {
    if killpg(pid, signal) == 0 {
      return (true, 0)
    }
    let groupErrno = errno
    if kill(pid, signal) == 0 {
      return (true, 0)
    }
    let processErrno = errno
    if processErrno == ESRCH || groupErrno == ESRCH {
      return (false, ESRCH)
    }
    return (false, processErrno)
  }

  private nonisolated static func isProcessAlive(pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    if kill(pid, 0) == 0 {
      return true
    }
    return errno == EPERM
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
