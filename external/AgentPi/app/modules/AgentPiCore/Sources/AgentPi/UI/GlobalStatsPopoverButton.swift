//
//  GlobalStatsPopoverButton.swift
//  AgentPi
//

import SwiftUI

/// A toolbar button that shows stats in a popover
public struct GlobalStatsPopoverButton: View {
  let claudeService: GlobalStatsService
  let codexService: CodexGlobalStatsService?
  let piService: CodexGlobalStatsService?
  @State private var isShowingPopover = false

  public init(
    claudeService: GlobalStatsService,
    codexService: CodexGlobalStatsService? = nil,
    piService: CodexGlobalStatsService? = nil
  ) {
    self.claudeService = claudeService
    self.codexService = codexService
    self.piService = piService
  }

  /// Backwards-compatible initializer
  public init(service: GlobalStatsService) {
    self.claudeService = service
    self.codexService = nil
    self.piService = nil
  }

  public var body: some View {
    Button(action: { isShowingPopover.toggle() }) {
      Image(systemName: "apple.terminal.on.rectangle")
        .font(.system(size: DesignTokens.IconSize.md))
        .foregroundColor(.brandPrimary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .help("View Stats")
    .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
      GlobalStatsMenuView(
        claudeService: claudeService,
        codexService: codexService,
        piService: piService,
        showQuitButton: false
      )
    }
  }
}
