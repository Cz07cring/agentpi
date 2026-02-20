import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct BatchTaskRunStoreTests {
  @MainActor
  @Test("markFinished preserves real exit code when stop was requested")
  func markFinishedPreservesRealExitCodeWhenCancelled() {
    let store = BatchTaskRunStore()
    let run = makeRun()
    store.appendRun(run, context: makeContext())

    #expect(store.markCancelRequested(runId: run.id))

    store.markFinished(runId: run.id, exitCode: 15)

    let finished = store.run(by: run.id)
    #expect(finished?.exitCode == 15)
    #expect(finished?.status == .failed)
    #expect(store.wasCancelled(runId: run.id))
    #expect(store.isCancelRequested(runId: run.id) == false)
  }

  @MainActor
  @Test("markCancelRequested only works for running runs")
  func markCancelRequestedOnlyForRunningRuns() {
    let store = BatchTaskRunStore()
    let run = makeRun(status: .succeeded)
    store.appendRun(run, context: makeContext())

    #expect(store.markCancelRequested(runId: run.id) == false)
  }

  @MainActor
  @Test("markFailedToStart clears pending cancellation flag")
  func markFailedToStartClearsCancellationFlag() {
    let store = BatchTaskRunStore()
    let run = makeRun()
    store.appendRun(run, context: makeContext())
    #expect(store.markCancelRequested(runId: run.id))

    store.markFailedToStart(runId: run.id, message: "boom")

    #expect(store.isCancelRequested(runId: run.id) == false)
    #expect(store.run(by: run.id)?.status == .failed)
  }

  @MainActor
  @Test("appendOutput truncates oversized logs and keeps tail")
  func appendOutputTruncatesAndKeepsTail() {
    let store = BatchTaskRunStore()
    let run = makeRun()
    store.appendRun(run, context: makeContext())

    store.appendOutput(runId: run.id, text: String(repeating: "a", count: 260_000), isError: false)
    store.appendOutput(runId: run.id, text: String(repeating: "b", count: 260_000), isError: false)

    let updated = store.run(by: run.id)
    let combined = updated?.output.map(\.text).joined() ?? ""

    #expect(store.isOutputTruncated(runId: run.id))
    #expect(store.truncatedOutputCharacterCount(runId: run.id) > 0)
    #expect(combined.count <= 240_000)
    #expect(combined.hasSuffix(String(repeating: "b", count: 100)))
  }

  @MainActor
  private func makeContext() -> BatchTaskExecutionContext {
    BatchTaskExecutionContext(
      provider: .pi,
      templateId: "template",
      projectPath: "/tmp/repo",
      prompt: "hi",
      cliConfiguration: CLICommandConfiguration(command: "pi", mode: .pi)
    )
  }

  @MainActor
  private func makeRun(status: BatchTaskRunStatus = .running) -> BatchTaskRun {
    BatchTaskRun(
      provider: .pi,
      templateId: "template",
      templateName: "Template",
      commandLine: "pi --json prompt",
      projectPath: "/tmp/repo",
      status: status
    )
  }
}
