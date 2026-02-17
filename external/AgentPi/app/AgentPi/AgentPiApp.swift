//
//  AgentPiApp.swift
//  AgentPi
//
//  Created by James Rochabrun on 1/11/26.
//

import SwiftUI
import AgentPiCore

// MARK: - App Delegate

/// Handles app lifecycle events for process cleanup
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  /// Shared provider instance - created here so it's available for lifecycle events
  let provider = AgentPiProvider()

  /// Update controller for Sparkle auto-updates
  let updateController = UpdateController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Note: We intentionally do NOT clean up orphaned processes here
    // because we can't distinguish between processes spawned by AgentPi
    // vs processes the user started directly in Terminal.app
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Terminate all active terminal processes on app quit
    provider.terminateAllTerminals()
    // Stop all dev servers spawned for web preview
    DevServerManager.shared.stopAllServers()
  }
}

// MARK: - App

@main
struct AgentPiApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @AppStorage(AgentPiDefaults.selectedLanguage) private var selectedLanguage: String = "system"

  init() {
    AgentPiDefaults.migrateIfNeeded()
  }

  var body: some Scene {
    WindowGroup {
      AgentPiSessionsView()
        .agentPi(appDelegate.provider)
        .id("window-lang-\(selectedLanguage)")
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(after: .appInfo) {
        CheckForUpdatesView(updateController: appDelegate.updateController)
      }
    }

    MenuBarExtra(
      isInserted: Binding(
        get: { appDelegate.provider.displaySettings.isMenuBarMode },
        set: { _ in }
      )
    ) {
      AgentPiMenuBarContent()
        .environment(\.agentPi, appDelegate.provider)
        .id("menubar-lang-\(selectedLanguage)")
    } label: {
      AgentPiMenuBarLabel(provider: appDelegate.provider)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .agentPi(appDelegate.provider)
        .id("settings-lang-\(selectedLanguage)")
    }
  }
}
