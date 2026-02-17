//
//  UpdateController.swift
//  AgentPi
//
//  Created by James Rochabrun on 1/23/26.
//

import Combine
import Foundation
import Sparkle
import SwiftUI

private final class AgentPiUpdaterDelegate: NSObject, SPUUpdaterDelegate {
  private let overriddenFeedURL: URL?

  init(overriddenFeedURL: URL?) {
    self.overriddenFeedURL = overriddenFeedURL
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    overriddenFeedURL?.absoluteString
  }
}

/// Controller for managing Sparkle software updates
@Observable
@MainActor
final class UpdateController {
  private enum FeedOverride {
    static let defaultsKey = "AgentPiUpdateFeedURL"
    static let envKey = "AGENTPI_UPDATE_FEED_URL"
  }

  private let updaterController: SPUStandardUpdaterController
  private let updaterDelegate: AgentPiUpdaterDelegate
  private var cancellable: AnyCancellable?

  var canCheckForUpdates = false

  init() {
    let overriddenFeedURL = Self.resolveFeedURLOverride()
    updaterDelegate = AgentPiUpdaterDelegate(overriddenFeedURL: overriddenFeedURL)

    // Create the updater controller with default UI
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: updaterDelegate,
      userDriverDelegate: nil
    )

    if let overriddenFeedURL {
      print("[Updater] Using overridden feed URL: \(overriddenFeedURL.absoluteString)")
    }

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

  private static func resolveFeedURLOverride() -> URL? {
    let envValue = ProcessInfo.processInfo.environment[FeedOverride.envKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
    let defaultsValue = UserDefaults.standard.string(forKey: FeedOverride.defaultsKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let rawValue = [envValue, defaultsValue].compactMap({ $0 }).first, !rawValue.isEmpty else {
      return nil
    }
    guard let url = URL(string: rawValue), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
      print("[Updater] Ignoring invalid feed override URL: \(rawValue)")
      return nil
    }
    return url
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
