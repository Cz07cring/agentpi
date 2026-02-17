//
//  UpdateController.swift
//  AgentPi
//
//  Created by James Rochabrun on 1/23/26.
//

import Combine
import Sparkle
import SwiftUI

/// Controller for managing Sparkle software updates
@Observable
@MainActor
final class UpdateController {
  private let updaterController: SPUStandardUpdaterController
  private var cancellable: AnyCancellable?

  var canCheckForUpdates = false

  init() {
    // Create the updater controller with default UI
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )

    // Observe when updates can be checked
    cancellable = updaterController.updater.publisher(for: \.canCheckForUpdates)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] canCheck in
        self?.canCheckForUpdates = canCheck
      }
  }

  /// Manually check for updates
  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }

  /// The underlying updater for advanced configuration
  var updater: SPUUpdater {
    updaterController.updater
  }
}

// MARK: - SwiftUI View for Check for Updates Menu Item

struct CheckForUpdatesView: View {
  var updateController: UpdateController

  var body: some View {
    Button("Check for Updates...") {
      updateController.checkForUpdates()
    }
    .disabled(!updateController.canCheckForUpdates)
  }
}
