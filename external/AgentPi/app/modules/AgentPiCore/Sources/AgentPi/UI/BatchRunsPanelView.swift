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

  private var runList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        ForEach(store.runs, id: \.id) { run in
          Button {
            selectedRunId = run.id
          } label: {
            HStack(spacing: 8) {
              Circle()
                .fill(statusColor(run.status))
                .frame(width: 8, height: 8)
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
  }

  private func runDetail(_ run: BatchTaskRun) -> some View {
    let visibleText = visibleOutputText(for: run)
    let hasVisibleText = !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let outputBottomAnchor = "batch-output-bottom-\(run.id)"

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(run.templateName)
          .font(.system(size: 12, weight: .semibold))
        Spacer(minLength: 4)
        if run.status == .running {
          Button(L10n.t("batch_runs.action.stop", "Stop")) {
            _ = runner.cancel(runId: run.id)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(.red)
        }
        Button(L10n.t("batch_runs.action.rerun", "Rerun")) {
          _ = runner.rerun(runId: run.id)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button(L10n.t("batch_runs.action.copy_command", "Copy Command")) {
          copyToClipboard(run.commandLine)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      Text(run.commandLine)
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .textSelection(.enabled)

      ScrollViewReader { proxy in
        ScrollView {
          Group {
            if !hasVisibleText {
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
                  }
                }
              }
            } else {
              Text(visibleText)
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

  private func statusColor(_ status: BatchTaskRunStatus) -> Color {
    switch status {
    case .running: return .orange
    case .succeeded: return .green
    case .failed: return .red
    }
  }

  private func statusLabel(_ run: BatchTaskRun) -> String {
    switch run.status {
    case .running:
      return L10n.t("batch_runs.status.running", "Running")
    case .succeeded:
      return L10n.t("batch_runs.status.success", "Success")
    case .failed:
      if run.exitCode == 130 {
        return L10n.t("batch_runs.status.cancelled", "Cancelled")
      }
      let code = run.exitCode ?? -1
      return L10n.f("batch_runs.status.failed_code", "Failed (%d)", code)
    }
  }

  private func timeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
  }

  private func elapsedSeconds(for run: BatchTaskRun, now: Date = Date()) -> Int {
    let end = run.endedAt ?? now
    return max(0, Int(end.timeIntervalSince(run.startedAt)))
  }

  private func visibleOutputText(for run: BatchTaskRun) -> String {
    let raw = run.output.map(\.text).joined()
    guard !raw.isEmpty else { return "" }

    // Normalize control-heavy terminal output so the panel doesn't appear blank.
    let strippedAnsi = raw
      .replacingOccurrences(of: #"\u{001B}\[[0-?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\u{001B}\][^\u{0007}\u{001B}]*(\u{0007}|\u{001B}\\)"#, with: "", options: .regularExpression)

    let normalizedControls = strippedAnsi
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\u{0008}", with: "")
      .replacingOccurrences(of: "\u{001B}", with: "")

    let lines = normalizedControls.components(separatedBy: "\n")
    var visibleLines: [String] = []
    var started = false
    var blankStreak = 0

    for line in lines {
      let isBlank = line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if !started {
        if isBlank { continue }
        started = true
      }

      if isBlank {
        blankStreak += 1
        if blankStreak > 2 { continue }
      } else {
        blankStreak = 0
      }
      visibleLines.append(line)
    }

    if visibleLines.isEmpty {
      return normalizedControls.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return visibleLines.joined(separator: "\n")
  }

  private func copyToClipboard(_ text: String) {
#if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
  }
}
