//
//  MobileRelayPanelView.swift
//  AgentPi
//
//  Displays one-click mobile relay handoff tasks.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

public struct MobileRelayPanelView: View {
  @Bindable var store: MobileRelayTaskStore
  let service: MobileRelayService
  @State private var selectedTaskId: String?

  public init(
    store: MobileRelayTaskStore,
    service: MobileRelayService
  ) {
    self.store = store
    self.service = service
  }

  public init() {
    self.store = .shared
    self.service = .shared
  }

  private var selectedTask: MobileRelayTask? {
    if let selectedTaskId,
      let found = store.tasks.first(where: { $0.id == selectedTaskId })
    {
      return found
    }
    return store.tasks.first
  }

  public var body: some View {
    VStack(spacing: 0) {
      if store.tasks.isEmpty {
        emptyState
      } else {
        taskList
        Divider()
        if let selectedTask {
          taskDetail(selectedTask)
        }
      }
    }
    .onAppear {
      if selectedTaskId == nil {
        selectedTaskId = store.tasks.first?.id
      }
    }
    .onChange(of: store.tasks.map(\.id)) { _, ids in
      guard !ids.isEmpty else {
        selectedTaskId = nil
        return
      }
      selectedTaskId = ids.first
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "iphone.gen3")
        .font(.title2)
        .foregroundColor(.secondary)
      Text(L10n.t("mobile_relay.empty.title", "No mobile relay tasks yet"))
        .font(.system(size: 13, weight: .semibold))
      Text(L10n.t("mobile_relay.empty.subtitle", "Use the handoff button in a session card to hand over work to mobile."))
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
  }

  private var taskList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        ForEach(store.tasks, id: \.id) { task in
          MobileRelayTaskRowView(
            task: task,
            isSelected: task.id == selectedTaskId,
            onSelect: { selectedTaskId = task.id },
            onStop: task.status == .running
              ? {
                _ = service.stop(taskId: task.id)
              }
              : nil
          )
        }
      }
      .padding(12)
    }
    .frame(minHeight: 140, maxHeight: 220)
  }

  private func taskDetail(_ task: MobileRelayTask) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(task.templateName)
          .font(.system(size: 12, weight: .semibold))
        Spacer(minLength: 4)

        if task.status == .running {
          Button(L10n.t("mobile_relay.action.stop", "Stop")) {
            _ = service.stop(taskId: task.id)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .tint(.red)
        }

        Button(L10n.t("mobile_relay.action.rerun", "Rerun")) {
          _ = service.rerun(taskId: task.id)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button(L10n.t("mobile_relay.action.copy_command", "Copy Command")) {
          copyToClipboard(task.commandLine)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button(L10n.t("mobile_relay.action.open_folder", "Open Folder")) {
          openPath(task.handoffJSONLPath)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      HStack(spacing: 12) {
        Text("\(task.sourceProvider.rawValue) -> \(task.targetProvider.rawValue)")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.secondary)
        Text(task.projectPath)
          .font(.system(size: 10, design: .monospaced))
          .foregroundColor(.secondary.opacity(0.8))
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Text(task.commandLine)
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .textSelection(.enabled)

      HStack(spacing: 8) {
        artifactButton(
          title: L10n.t("mobile_relay.artifact.jsonl", "JSONL"),
          path: task.handoffJSONLPath
        )
        artifactButton(
          title: L10n.t("mobile_relay.artifact.markdown", "Markdown"),
          path: task.handoffMarkdownPath
        )
      }

      ScrollView {
        Text(task.output.map(\.text).joined())
          .font(.system(size: 11, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .textSelection(.enabled)
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

  private func artifactButton(title: String, path: String) -> some View {
    Button(title) {
      openPath(path)
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  private func copyToClipboard(_ text: String) {
#if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
  }

  private func openPath(_ path: String) {
#if canImport(AppKit)
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let url = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: path) {
      NSWorkspace.shared.activateFileViewerSelecting([url])
      return
    }
    NSWorkspace.shared.open(url.deletingLastPathComponent())
#endif
  }
}
