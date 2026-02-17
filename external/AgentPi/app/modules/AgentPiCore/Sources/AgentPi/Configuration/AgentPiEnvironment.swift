//
//  AgentPiEnvironment.swift
//  AgentPi
//
//  SwiftUI environment integration for AgentPi
//

import SwiftUI

// MARK: - Environment Key

private struct AgentPiProviderKey: EnvironmentKey {
  static let defaultValue: AgentPiProvider? = nil
}

extension EnvironmentValues {
  /// Access to the AgentPi provider from the environment
  ///
  /// Use this to access AgentPi services from any view in the hierarchy.
  ///
  /// ## Example
  /// ```swift
  /// struct MyView: View {
  ///   @Environment(\.agentPi) private var agentPi
  ///
  ///   var body: some View {
  ///     if let provider = agentPi {
  ///       Text("Tokens: \(provider.statsService.formattedTotalTokens)")
  ///     }
  ///   }
  /// }
  /// ```
  public var agentPi: AgentPiProvider? {
    get { self[AgentPiProviderKey.self] }
    set { self[AgentPiProviderKey.self] = newValue }
  }
}

// MARK: - View Modifier

/// View modifier that injects AgentPi provider into the environment
private struct AgentPiModifier: ViewModifier {
  let provider: AgentPiProvider
  let themeManager: ThemeManager

  init(provider: AgentPiProvider) {
    self.provider = provider
    self.themeManager = provider.themeManager
  }

  func body(content: Content) -> some View {
    content
      .environment(\.agentPi, provider)
      .environment(provider.statsService)
      .environment(provider.displaySettings)
      .environment(themeManager)
      .environment(\.runtimeTheme, themeManager.currentTheme)
  }
}

extension View {
  /// Configures the view hierarchy with an AgentPi provider
  ///
  /// Use this modifier at the root of your view hierarchy to make
  /// AgentPi services available to all child views.
  ///
  /// ## Example
  /// ```swift
  /// @State private var provider = AgentPiProvider()
  ///
  /// var body: some Scene {
  ///   WindowGroup {
  ///     ContentView()
  ///       .agentPi(provider)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter provider: The AgentPi provider to inject
  /// - Returns: A view with AgentPi configured in the environment
  public func agentPi(_ provider: AgentPiProvider) -> some View {
    modifier(AgentPiModifier(provider: provider))
  }

  /// Configures the view hierarchy with a default AgentPi provider
  ///
  /// Creates a new `AgentPiProvider` with default configuration.
  /// For most cases, prefer passing an explicit provider to share
  /// state across windows/scenes.
  ///
  /// - Returns: A view with AgentPi configured in the environment
  public func agentPi() -> some View {
    modifier(AgentPiModifier(provider: AgentPiProvider()))
  }

  /// Configures the view hierarchy with a custom AgentPi configuration
  ///
  /// Creates a new `AgentPiProvider` with the specified configuration.
  ///
  /// - Parameter configuration: Custom configuration for AgentPi
  /// - Returns: A view with AgentPi configured in the environment
  public func agentPi(configuration: AgentPiConfiguration) -> some View {
    modifier(AgentPiModifier(provider: AgentPiProvider(configuration: configuration)))
  }
}
