//
//  MobileRelayTaskRowView.swift
//  AgentPi
//
//  Compact row for mobile relay tasks.
//

import SwiftUI

public struct MobileRelayTaskRowView: View {
  let task: MobileRelayTask
  let isSelected: Bool
  let onSelect: () -> Void
  let onStop: (() -> Void)?

  public init(
    task: MobileRelayTask,
    isSelected: Bool,
    onSelect: @escaping () -> Void,
    onStop: (() -> Void)? = nil
  ) {
    self.task = task
    self.isSelected = isSelected
    self.onSelect = onSelect
    self.onStop = onStop
  }

  public var body: some View {
    HStack(spacing: 8) {
      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
        Text(task.targetProvider.rawValue)
          .font(.system(size: 11, weight: .semibold))
        Text(task.templateName)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
        Text(task.sessionShortId)
          .font(.system(size: 10, design: .monospaced))
          .foregroundColor(.secondary.opacity(0.8))
        Spacer(minLength: 4)
        Text(statusText)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
      }
      .contentShape(Rectangle())
      .onTapGesture(perform: onSelect)

      if task.status == .running, let onStop {
        Button {
          onStop()
        } label: {
          Image(systemName: "stop.fill")
            .font(.system(size: 10, weight: .bold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.mini)
        .tint(.red)
        .help(L10n.t("mobile_relay.action.stop", "Stop"))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
    )
  }

  private var statusColor: Color {
    switch task.status {
    case .running: return .orange
    case .succeeded: return .green
    case .failed: return .red
    case .cancelled: return .gray
    }
  }

  private var statusText: String {
    switch task.status {
    case .running:
      return L10n.t("mobile_relay.status.running", "Running")
    case .succeeded:
      return L10n.t("mobile_relay.status.success", "Success")
    case .failed:
      let code = task.exitCode ?? -1
      return L10n.f("mobile_relay.status.failed_code", "Failed (%d)", code)
    case .cancelled:
      return L10n.t("mobile_relay.status.cancelled", "Cancelled")
    }
  }
}
