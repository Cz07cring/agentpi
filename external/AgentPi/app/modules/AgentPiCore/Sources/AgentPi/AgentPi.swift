//
//  AgentPi.swift
//  AgentPi
//
//  CLI Session Monitoring Library for Claude Code
//

import Foundation

/// AgentPi version
public let agentPiVersion = "1.0.0"

// MARK: - Quick Start
//
// AgentPi provides a simple API for monitoring Claude Code CLI sessions.
//
// ## Basic Usage (Recommended)
//
// ```swift
// import AgentPi
//
// @main
// struct MyApp: App {
//   @State private var provider = AgentPiProvider()
//
//   var body: some Scene {
//     WindowGroup {
//       AgentPiSessionsView()
//         .agentPi(provider)
//     }
//     .windowStyle(.hiddenTitleBar)
//
//     MenuBarExtra {
//       AgentPiMenuBarContent()
//         .environment(\.agentPi, provider)
//     } label: {
//       AgentPiMenuBarLabel(provider: provider)
//     }
//   }
// }
// ```
//
// ## Custom Configuration
//
// ```swift
// var config = AgentPiConfiguration.default
// config.enableDebugLogging = true
// let provider = AgentPiProvider(configuration: config)
// ```
//
// ## Direct Service Access
//
// For advanced usage, access services directly from the provider:
//
// ```swift
// let stats = provider.statsService.formattedTotalTokens
// let sessions = provider.sessionsViewModel.totalSessionCount
// ```

// MARK: - Re-exports

// Configuration types are exported via their public declarations in:
// - Configuration/AgentPiConfiguration.swift
// - Configuration/AgentPiProvider.swift
// - Configuration/AgentPiEnvironment.swift
// - Configuration/AgentPiViews.swift
// - Configuration/AgentPiDefaults.swift
