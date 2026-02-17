//
//  StatsProviderSegmentedControl.swift
//  AgentPi
//
//  Compact segmented control for switching between Claude and Codex stats.
//

import SwiftUI

/// A compact segmented control for the stats view with underline indicator
public struct StatsProviderSegmentedControl: View {
  @Binding var selectedProvider: SessionProviderKind
  let claudeSessionCount: Int
  let codexSessionCount: Int
  let piSessionCount: Int
  let showCodex: Bool
  let showPi: Bool

  public init(
    selectedProvider: Binding<SessionProviderKind>,
    claudeSessionCount: Int = 0,
    codexSessionCount: Int = 0,
    piSessionCount: Int = 0,
    showCodex: Bool = true,
    showPi: Bool = false
  ) {
    self._selectedProvider = selectedProvider
    self.claudeSessionCount = claudeSessionCount
    self.codexSessionCount = codexSessionCount
    self.piSessionCount = piSessionCount
    self.showCodex = showCodex
    self.showPi = showPi
  }

  public var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        segmentButton(for: .claude, count: claudeSessionCount)
        if showCodex {
          segmentButton(for: .codex, count: codexSessionCount)
        }
        if showPi {
          segmentButton(for: .pi, count: piSessionCount)
        }
        Spacer()
      }

      Rectangle()
        .fill(Color.borderSubtle.opacity(0.35))
        .frame(height: 1)
        .padding(.top, 6)
    }
    .padding(.horizontal, 4)
  }

  private func segmentButton(for provider: SessionProviderKind, count: Int) -> some View {
    Button {
      selectedProvider = provider
    } label: {
      HStack(spacing: 6) {
        Text("\(provider.rawValue) (\(count))")
          .font(.system(.subheadline, weight: .medium))
          .foregroundColor(
            selectedProvider == provider
              ? Color.brandPrimary(for: provider)
              : .secondary
          )

        if provider == .codex {
          Text("Beta")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(selectedProvider == .codex ? .secondary : .tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(selectedProvider == .codex ? Color.gray.opacity(0.2) : Color.clear)
            .clipShape(Capsule())
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
