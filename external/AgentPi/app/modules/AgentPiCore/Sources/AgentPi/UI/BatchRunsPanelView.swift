//
//  BatchRunsPanelView.swift
//  AgentPi
//
//  Displays one-off batch task executions from command templates.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

private let batchTimeFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "HH:mm:ss"
  return f
}()

public struct BatchRunsPanelView: View {
  @Bindable var store: BatchTaskRunStore
  let runner: BatchTaskRunnerService
  @State private var selectedRunId: String?

  public init(
    store: BatchTaskRunStore,
    runner: BatchTaskRunnerService
  ) {
    self.store = store
    self.runner = runner
  }

  public init() {
    self.store = .shared
    self.runner = .shared
  }

  private var selectedRun: BatchTaskRun? {
    if let selectedRunId,
      let found = store.runs.first(where: { $0.id == selectedRunId })
    {
      return found
    }
    return store.runs.first
  }

  public var body: some View {
    VStack(spacing: 0) {
      if store.runs.isEmpty {
        emptyState
      } else {
        runList
        Divider()
        if let selectedRun {
          runDetail(selectedRun)
        }
      }
    }
    .onAppear {
      if selectedRunId == nil {
        selectedRunId = store.runs.first?.id
      }
    }
    .onChange(of: store.runs.map(\.id)) { _, ids in
      guard !ids.isEmpty else {
        selectedRunId = nil
        return
      }
      if let selectedRunId, ids.contains(selectedRunId) {
        return
      }
      selectedRunId = ids.first
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "terminal")
        .font(.title2)
        .foregroundColor(.secondary)
      Text(L10n.t("batch_runs.empty.title", "No batch runs yet"))
        .font(.system(size: 13, weight: .semibold))
      Text(L10n.t("batch_runs.empty.subtitle", "Use a batch template from Start Session to run one-off commands."))
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
  }

  private var hasCompletedRuns: Bool {
    store.runs.contains { $0.status != .running }
  }

  private var runList: some View {
    VStack(spacing: 0) {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(store.runs, id: \.id) { run in
            Button {
              selectedRunId = run.id
            } label: {
              HStack(spacing: 8) {
                statusIndicator(run)
                Text(run.provider.rawValue)
                  .font(.system(size: 11, weight: .semibold))
                Text(run.templateName)
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                Text(timeString(run.startedAt))
                  .font(.system(size: 10, design: .monospaced))
                  .foregroundColor(.secondary.opacity(0.8))
                Spacer(minLength: 4)
                Text(statusLabel(run))
                  .font(.system(size: 10))
                  .foregroundColor(.secondary)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 8)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(run.id == selectedRunId ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(12)
      }
      .frame(minHeight: 140, maxHeight: 200)

      if hasCompletedRuns {
        Divider()
        HStack {
          Spacer()
          Button(L10n.t("batch_runs.action.clear_completed", "Clear Completed")) {
            store.removeCompletedRuns()
          }
          .buttonStyle(.borderless)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
        }
      }
    }
  }

  @ViewBuilder
  private func statusIndicator(_ run: BatchTaskRun) -> some View {
    if run.status == .running {
      Circle()
        .fill(statusColor(run))
        .frame(width: 8, height: 8)
        .overlay(
          Circle()
            .stroke(statusColor(run).opacity(0.4), lineWidth: 2)
        )
    } else {
      Circle()
        .fill(statusColor(run))
        .frame(width: 8, height: 8)
    }
  }

  private func runDetail(_ run: BatchTaskRun) -> some View {
    let visibleSegments = visibleOutputSegments(for: run)
    let hasVisibleText = !visibleSegments.isEmpty
    let visibleText = combinedVisibleText(from: visibleSegments)
    let outputBottomAnchor = "batch-output-bottom-\(run.id)"
    let stopRequested = isStopRequested(run)
    let outputWasTruncated = store.isOutputTruncated(runId: run.id)
    let truncatedCharacters = store.truncatedOutputCharacterCount(runId: run.id)

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(run.templateName)
          .font(.system(size: 12, weight: .semibold))
        Spacer(minLength: 4)
        if run.status == .running {
          Button(
            stopRequested
              ? L10n.t("batch_runs.action.stopping", "Stopping...")
              : L10n.t("batch_runs.action.stop", "Stop")
          ) {
            _ = runner.cancel(runId: run.id)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(.red)
          .disabled(stopRequested)
        }
        Button(L10n.t("batch_runs.action.rerun", "Rerun")) {
          _ = runner.rerun(runId: run.id)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(run.status == .running)

        Button(L10n.t("batch_runs.action.copy_command", "Copy Command")) {
          copyToClipboard(run.commandLine)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button(L10n.t("batch_runs.action.copy_output", "Copy Output")) {
          copyToClipboard(visibleText)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!hasVisibleText)
      }

      Text(run.commandLine)
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .textSelection(.enabled)

      HStack(spacing: 10) {
        Text(statusLabel(run))
        if run.status == .running {
          TimelineView(.periodic(from: Date(), by: 1)) { context in
            Text(elapsedFormatted(for: run, now: context.date))
          }
        } else {
          Text(elapsedFormatted(for: run, now: run.endedAt ?? run.startedAt))
        }
        Text(L10n.f("batch_runs.meta.chunks", "%d chunks", run.output.count))
        if outputWasTruncated {
          Text(
            L10n.f(
              "batch_runs.meta.output_truncated",
              "Output truncated (dropped ~%d chars)",
              truncatedCharacters
            )
          )
            .foregroundColor(.orange)
        }
      }
      .font(.system(size: 10, design: .monospaced))
      .foregroundColor(.secondary)

      ScrollViewReader { proxy in
        ScrollView {
          Group {
            if !hasVisibleText {
              if run.status == .running {
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                  VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("batch_runs.output.waiting", "Task is running, waiting for CLI output..."))
                    Text(
                      L10n.f(
                        "batch_runs.output.elapsed_seconds",
                        "Elapsed: %ds. You can click Stop to cancel.",
                        elapsedSeconds(for: run, now: context.date)
                      )
                    )
                      .foregroundColor(.secondary)
                    if !run.output.isEmpty {
                      Text(
                        L10n.f(
                          "batch_runs.output.chunks_received",
                          "Received %d output chunk(s), but no visible text yet.",
                          run.output.count
                        )
                      )
                        .foregroundColor(.secondary)

                      if let lastChunk = run.output.last?.text {
                        Text(
                          L10n.f(
                            "batch_runs.output.raw_preview",
                            "Last raw chunk (escaped): %@",
                            escapedPreview(lastChunk)
                          )
                        )
                          .foregroundColor(.secondary.opacity(0.8))
                      }
                    }
                  }
                }
              } else {
                VStack(alignment: .leading, spacing: 6) {
                  Text(
                    L10n.f(
                      "batch_runs.output.finished_no_output",
                      "Task ended with no visible output (exit code=%d).",
                      run.exitCode ?? -1
                    )
                  )
                  Text(
                    L10n.f(
                      "batch_runs.output.chunks_received",
                      "Received %d output chunk(s), but no visible text yet.",
                      run.output.count
                    )
                  )
                    .foregroundColor(.secondary)
                  if let lastChunk = run.output.last?.text {
                    Text(
                      L10n.f(
                        "batch_runs.output.raw_preview",
                        "Last raw chunk (escaped): %@",
                        escapedPreview(lastChunk)
                      )
                    )
                      .foregroundColor(.secondary.opacity(0.8))
                  }
                }
              }
            } else {
              // Render per-chunk with stderr in red
              VStack(alignment: .leading, spacing: 0) {
                ForEach(visibleSegments) { segment in
                  Text(segment.text)
                    .foregroundColor(segment.isError ? .red.opacity(0.85) : .primary)
                }
              }
              .id(outputBottomAnchor)
            }
          }
          .font(.system(size: 11, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .textSelection(.enabled)
        }
        .onAppear {
          guard hasVisibleText else { return }
          proxy.scrollTo(outputBottomAnchor, anchor: .bottom)
        }
        .onChange(of: run.output.count) { _, _ in
          guard hasVisibleText else { return }
          proxy.scrollTo(outputBottomAnchor, anchor: .bottom)
        }
      }
      .frame(minHeight: 120, maxHeight: .infinity)
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.primary.opacity(0.05))
      )
    }
    .padding(12)
  }

  private func statusColor(_ run: BatchTaskRun) -> Color {
    if isStopRequested(run) {
      return .red
    }
    switch run.status {
    case .running: return .orange
    case .succeeded: return .green
    case .failed: return .red
    }
  }

  private func statusLabel(_ run: BatchTaskRun) -> String {
    switch run.status {
    case .running:
      if isStopRequested(run) {
        return L10n.t("batch_runs.status.stopping", "Stopping...")
      }
      return L10n.t("batch_runs.status.running", "Running")
    case .succeeded:
      return L10n.t("batch_runs.status.success", "Success")
    case .failed:
      if store.wasCancelled(runId: run.id) || run.exitCode == 130 {
        return L10n.t("batch_runs.status.cancelled", "Cancelled")
      }
      let code = run.exitCode ?? -1
      return L10n.f("batch_runs.status.failed_code", "Failed (%d)", code)
    }
  }

  private func timeString(_ date: Date) -> String {
    batchTimeFormatter.string(from: date)
  }

  private func elapsedSeconds(for run: BatchTaskRun, now: Date = Date()) -> Int {
    let end = run.endedAt ?? now
    return max(0, Int(end.timeIntervalSince(run.startedAt)))
  }

  private func elapsedFormatted(for run: BatchTaskRun, now: Date) -> String {
    let seconds = elapsedSeconds(for: run, now: now)
    if seconds < 60 {
      return "\(seconds)s"
    }
    let minutes = seconds / 60
    let remaining = seconds % 60
    return "\(minutes)m \(remaining)s"
  }

  private func isStopRequested(_ run: BatchTaskRun) -> Bool {
    run.status == .running && store.isCancelRequested(runId: run.id)
  }

  // MARK: - Per-chunk output with stderr coloring

  private struct OutputSegment: Identifiable {
    let id: Int
    let text: String
    let isError: Bool
  }

  private func visibleOutputSegments(for run: BatchTaskRun) -> [OutputSegment] {
    guard !run.output.isEmpty else { return [] }
    var segments: [OutputSegment] = []
    for (index, chunk) in run.output.enumerated() {
      let cleaned = cleanChunkText(chunk.text)
      let beautified = beautifyJSONLines(cleaned)
      guard hasRenderableContent(beautified) else { continue }
      segments.append(OutputSegment(id: index, text: beautified, isError: chunk.isError))
    }
    return segments
  }

  private func combinedVisibleText(from segments: [OutputSegment]) -> String {
    guard !segments.isEmpty else { return "" }
    return segments.map(\.text).joined()
  }

  private func cleanChunkText(_ raw: String) -> String {
    guard !raw.isEmpty else { return "" }
    let strippedAnsi = raw
      .replacingOccurrences(of: #"\u{001B}\[[0-?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\u{001B}\][^\u{0007}\u{001B}]*(\u{0007}|\u{001B}\\)"#, with: "", options: .regularExpression)
    let normalizedControls = strippedAnsi
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\u{0008}", with: "")
      .replacingOccurrences(of: "\u{001B}", with: "")
    let filteredScalars = normalizedControls.unicodeScalars.filter { scalar in
      if scalar == "\n" || scalar == "\t" { return true }
      return !CharacterSet.controlCharacters.contains(scalar)
    }
    return String(String.UnicodeScalarView(filteredScalars))
  }

  private func beautifyJSONLines(_ text: String) -> String {
    guard !text.isEmpty else { return text }
    let lines = text.components(separatedBy: .newlines)
    var outputLines: [String] = []
    outputLines.reserveCapacity(lines.count)
    var beautifiedCount = 0

    for line in lines {
      let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        outputLines.append("")
        continue
      }

      if let prettyJSON = prettifyJSON(trimmed) {
        beautifiedCount += 1
        outputLines.append(prettyJSON)
      } else {
        outputLines.append(line)
      }
    }

    guard beautifiedCount > 0 else { return text }
    return outputLines.joined(separator: "\n")
  }

  private func prettifyJSON(_ raw: String) -> String? {
    guard raw.hasPrefix("{") || raw.hasPrefix("[") else { return nil }
    guard let data = raw.data(using: .utf8) else { return nil }
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }

    let options: JSONSerialization.WritingOptions = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes
    ]
    guard let prettyData = try? JSONSerialization.data(withJSONObject: object, options: options) else {
      return nil
    }
    return String(data: prettyData, encoding: .utf8)
  }

  private func hasRenderableContent(_ text: String) -> Bool {
    for scalar in text.unicodeScalars {
      if CharacterSet.controlCharacters.contains(scalar) { continue }
      if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
      return true
    }
    return false
  }

  private func escapedPreview(_ text: String, limit: Int = 240) -> String {
    var pieces: [String] = []
    pieces.reserveCapacity(min(limit, text.count))

    var consumed = 0
    for scalar in text.unicodeScalars {
      if consumed >= limit {
        pieces.append("...")
        break
      }

      if scalar == "\n" {
        pieces.append("\\n")
      } else if scalar == "\r" {
        pieces.append("\\r")
      } else if scalar == "\t" {
        pieces.append("\\t")
      } else if CharacterSet.controlCharacters.contains(scalar) {
        pieces.append(String(format: "\\u{%04X}", scalar.value))
      } else {
        pieces.append(String(scalar))
      }

      consumed += 1
    }

    return pieces.joined()
  }

  private func copyToClipboard(_ text: String) {
#if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
  }
}
