//
//  AgentPiViews.swift
//  AgentPi
//
//  Pre-configured view components for AgentPi
//

import SwiftUI

// MARK: - RemoveTitleToolbarModifier

/// A view modifier that removes the toolbar title on macOS 15+
private struct RemoveTitleToolbarModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 15.0, *) {
      content.toolbar(removing: .title)
    } else {
      content
    }
  }
}

// MARK: - AgentPiSessionsView

/// Pre-configured sessions view that reads from the environment
///
/// This view automatically gets its dependencies from the AgentPi provider
/// in the environment. Make sure to apply `.agentPi()` modifier to a parent view.
///
/// ## Example
/// ```swift
/// WindowGroup {
///   AgentPiSessionsView()
///     .agentPi(provider)
/// }
/// ```
public struct AgentPiSessionsView: View {
  @Environment(\.agentPi) private var agentPi
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  public init() {}

  public var body: some View {
    if let provider = agentPi {
      sessionsListView(provider: provider)
    } else {
      missingProviderView
    }
  }

  @ViewBuilder
  private func sessionsListView(provider: AgentPiProvider) -> some View {
    MultiProviderSessionsListView(
      claudeViewModel: provider.claudeSessionsViewModel,
      codexViewModel: provider.codexSessionsViewModel,
      piViewModel: provider.piSessionsViewModel,
      columnVisibility: $columnVisibility,
      intelligenceViewModel: provider.intelligenceViewModel
    )
      .frame(minWidth: 1200, minHeight: 750)
      .modifier(RemoveTitleToolbarModifier())
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack {
            Spacer()
            // Stats button (popover mode only)
            if provider.displaySettings.isPopoverMode {
              GlobalStatsPopoverButton(
                claudeService: provider.statsService,
                codexService: provider.codexStatsService,
                piService: provider.piStatsService
              )
            }
          }
          .frame(maxWidth: .infinity)
        }
      }
  }

  private var missingProviderView: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("AgentPi provider not found")
        .font(.headline)
      Text("Add .agentPi() modifier to a parent view")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - AgentPiMenuBarContent

/// Pre-configured menu bar content for MenuBarExtra
///
/// Use this as the content of a MenuBarExtra to show global stats.
///
/// ## Example
/// ```swift
/// MenuBarExtra("Stats", systemImage: "sparkle") {
///   AgentPiMenuBarContent()
///     .environment(\.agentPi, provider)
/// }
/// ```
public struct AgentPiMenuBarContent: View {
  @Environment(\.agentPi) private var agentPi

  public init() {}

  public var body: some View {
    if let provider = agentPi {
      GlobalStatsMenuView(
        claudeService: provider.statsService,
        codexService: provider.codexStatsService,
        piService: provider.piStatsService,
        sessionsViewModel: provider.sessionsViewModel
      )
    } else {
      Text("AgentPi provider not found")
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - AgentPiMenuBarLabel

/// Pre-configured label for MenuBarExtra
///
/// Shows an icon with token count in the menu bar.
///
/// ## Example
/// ```swift
/// @State private var provider = AgentPiProvider()
///
/// MenuBarExtra {
///   AgentPiMenuBarContent()
///     .environment(\.agentPi, provider)
/// } label: {
///   AgentPiMenuBarLabel(provider: provider)
/// }
/// ```
public struct AgentPiMenuBarLabel: View {
  let provider: AgentPiProvider

  public init(provider: AgentPiProvider) {
    self.provider = provider
  }

  public var body: some View {
    Image(systemName: "apple.terminal.on.rectangle")
  }
}
