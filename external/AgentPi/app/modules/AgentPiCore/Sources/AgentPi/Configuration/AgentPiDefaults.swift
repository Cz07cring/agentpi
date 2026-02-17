//
//  AgentPiDefaults.swift
//  AgentPi
//
//  Centralized UserDefaults keys for AgentPi
//

import Foundation

/// Centralized UserDefaults keys for AgentPi
///
/// All keys are namespaced with `com.ring.agentpi.` prefix to avoid collisions.
///
/// ## Usage
/// ```swift
/// // Read
/// let showLast = UserDefaults.standard.bool(forKey: AgentPiDefaults.showLastMessage)
///
/// // Write
/// UserDefaults.standard.set(true, forKey: AgentPiDefaults.showLastMessage)
/// ```
public enum AgentPiDefaults {

  /// Prefix for all AgentPi UserDefaults keys
  public static let keyPrefix = "com.ring.agentpi."
  private static let legacyPrefixedNamespaces = ["com.agenthub.", "com.agentpi."]

  // MARK: - Session Settings

  /// Whether to show the last message instead of first in session rows
  /// Type: Bool (default: false)
  public static let showLastMessage = "\(keyPrefix)sessions.showLastMessage"

  /// Seconds to wait before triggering approval alert sound
  /// Type: Int (default: 0)
  public static let approvalTimeout = "\(keyPrefix)sessions.approvalTimeout"

  // MARK: - Notification Settings

  /// Whether notification sounds are enabled
  /// Type: Bool (default: true)
  public static let notificationSoundsEnabled = "\(keyPrefix)notifications.soundsEnabled"

  /// Persisted selected repositories (JSON-encoded array of paths)
  /// Type: Data (JSON-encoded [String])
  /// Note: Used with provider suffix (e.g., `.claude` or `.codex`) for provider-specific storage
  public static let selectedRepositories = "\(keyPrefix)sessions.selectedRepositories"

  /// Persisted monitored session IDs (JSON-encoded array of session IDs)
  /// Type: Data (JSON-encoded [String])
  public static let monitoredSessionIds = "\(keyPrefix)sessions.monitoredSessionIds"

  /// Persisted session IDs that have terminal view enabled
  /// Type: Data (JSON-encoded [String])
  public static let sessionsWithTerminalView = "\(keyPrefix)sessions.sessionsWithTerminalView"

  // MARK: - Provider Settings

  /// Base key for enabled providers
  /// Usage: Use with provider suffix, e.g. `enabledProviders + ".claude"`
  /// Type: Bool (default: true)
  public static let enabledProviders = "\(keyPrefix)settings.enabledProviders"

  // MARK: - CLI Command Settings

  /// Custom Claude CLI command name
  /// Type: String (default: "claude")
  public static let claudeCommand = "\(keyPrefix)cli.claudeCommand"

  /// Custom Codex CLI command name
  /// Type: String (default: "codex")
  public static let codexCommand = "\(keyPrefix)cli.codexCommand"

  /// Custom AgentPi CLI command name
  /// Type: String (default: "pi")
  public static let piCommand = "\(keyPrefix)cli.piCommand"

  /// Whether Claude command was set by developer (not user-editable)
  /// Type: Bool (default: false)
  public static let claudeCommandLockedByDeveloper = "\(keyPrefix)cli.claudeCommandLocked"

  /// Whether Codex command was set by developer (not user-editable)
  /// Type: Bool (default: false)
  public static let codexCommandLockedByDeveloper = "\(keyPrefix)cli.codexCommandLocked"

  /// Whether AgentPi command was set by developer (not user-editable)
  /// Type: Bool (default: false)
  public static let piCommandLockedByDeveloper = "\(keyPrefix)cli.piCommandLocked"

  /// Selected provider in side panel segmented control
  /// Type: String (default: "AgentPi")
  public static let selectedSidePanelProvider = "\(keyPrefix)sidepanel.selectedProvider"

  // MARK: - Stats Settings

  /// Selected provider in stats view segmented control
  /// Type: String (default: "Claude")
  public static let selectedStatsProvider = "\(keyPrefix)stats.selectedProvider"

  // MARK: - UI Settings

  /// Monitoring panel layout mode (list, 2-column, 3-column grid)
  /// Type: Int (default: 0 = list)
  public static let monitoringPanelLayoutMode = "\(keyPrefix)ui.monitoringPanelLayoutMode"

  /// Hub layout mode (single, list, 2-column, 3-column)
  /// Type: Int (default: 0 = single)
  public static let hubLayoutMode = "\(keyPrefix)hub.layoutMode"

  /// Whether the selected sessions panel is expanded
  /// Type: Bool (default: true)
  public static let selectedSessionsPanelExpanded = "\(keyPrefix)ui.selectedSessionsPanelExpanded"

  /// Selected sessions panel size mode (collapsed, small, medium, full)
  /// Type: Int (default: 1 = small)
  public static let selectedSessionsPanelSizeMode = "\(keyPrefix)ui.selectedSessionsPanelSizeMode"

  // MARK: - Feature Flags

  /// Whether smart mode (AI-powered orchestration planning) is enabled
  /// Type: Bool (default: false)
  public static let smartModeEnabled = "\(keyPrefix)features.smartModeEnabled"

  /// Timeout for git worktree operations in seconds.
  /// Type: Int (default: 30)
  public static let worktreeTimeoutSeconds = "\(keyPrefix)worktree.timeout.seconds"

  /// Keep launcher form values after launch failure so users can retry quickly.
  /// Type: Bool (default: true)
  public static let launchPreserveFormOnFailure = "\(keyPrefix)launch.preserveFormOnFailure"

  /// Whether launcher guided hints are enabled.
  /// Type: Bool (default: true)
  public static let uxGuidedHintsEnabled = "\(keyPrefix)ux.guidedHintsEnabled"

  /// Whether launcher runs in expert quick mode.
  /// Type: Bool (default: false)
  public static let uxExpertQuickMode = "\(keyPrefix)ux.expertQuickMode"

  /// Whether launcher allows partial start when some selected CLIs are missing.
  /// Type: Bool (default: true)
  public static let launchPartialWhenCliMissing = "\(keyPrefix)ux.launch.partial_when_cli_missing"

  /// Maximum seconds a view should remain in loading state without actionable feedback.
  /// Type: Int (default: 8)
  public static let maxLoadingWithoutFeedbackSeconds = "\(keyPrefix)ui.maxLoadingWithoutFeedback.seconds"

  // MARK: - Network / Proxy

  /// Whether custom proxy environment variables should be injected into CLI sessions.
  /// Type: Bool (default: false)
  public static let proxyEnabled = "\(keyPrefix)network.proxy.enabled"

  /// Default HTTP proxy URL.
  public static let defaultProxyHTTP = "http://127.0.0.1:7890"

  /// Default HTTPS proxy URL.
  public static let defaultProxyHTTPS = "http://127.0.0.1:7890"

  /// Default ALL_PROXY value.
  public static let defaultProxyALL = "socks5://127.0.0.1:7890"

  /// Default NO_PROXY value.
  public static let defaultProxyNO = "localhost,127.0.0.1"

  /// HTTP proxy URL for CLI sessions.
  /// Type: String (default: "http://127.0.0.1:7890")
  public static let proxyHTTP = "\(keyPrefix)network.proxy.http"

  /// HTTPS proxy URL for CLI sessions.
  /// Type: String (default: "http://127.0.0.1:7890")
  public static let proxyHTTPS = "\(keyPrefix)network.proxy.https"

  /// ALL_PROXY value for CLI sessions (supports socks5://...)
  /// Type: String (default: "socks5://127.0.0.1:7890")
  public static let proxyALL = "\(keyPrefix)network.proxy.all"

  /// NO_PROXY value for CLI sessions.
  /// Type: String (default: "localhost,127.0.0.1")
  public static let proxyNO = "\(keyPrefix)network.proxy.no"

  // MARK: - Theme Settings

  /// Selected color theme name
  /// Type: String (default: "claude")
  public static let selectedTheme = "\(keyPrefix)theme.selected"

  /// Selected app language code
  /// Type: String (default: "system")
  /// Supported: system, en, zh-Hans, ko, ja, vi
  public static let selectedLanguage = "\(keyPrefix)ui.language"

  /// Custom primary color hex value
  /// Type: String (default: "#7C3AED")
  public static let customPrimaryHex = "\(keyPrefix)theme.customPrimaryHex"

  /// Custom secondary color hex value
  /// Type: String (default: "#FFB000")
  public static let customSecondaryHex = "\(keyPrefix)theme.customSecondaryHex"

  /// Custom tertiary color hex value
  /// Type: String (default: "#64748B")
  public static let customTertiaryHex = "\(keyPrefix)theme.customTertiaryHex"

  /// Active YAML theme primary color hex value cache
  /// Type: String (default: unset)
  public static let yamlPrimaryHex = "\(keyPrefix)theme.yamlPrimaryHex"

  /// Active YAML theme secondary color hex value cache
  /// Type: String (default: unset)
  public static let yamlSecondaryHex = "\(keyPrefix)theme.yamlSecondaryHex"

  /// Active YAML theme tertiary color hex value cache
  /// Type: String (default: unset)
  public static let yamlTertiaryHex = "\(keyPrefix)theme.yamlTertiaryHex"

  /// Installed bundled theme version for a given theme name
  /// Type: String (default: unset)
  /// Usage: `UserDefaults.standard.string(forKey: AgentPiDefaults.installedBundledThemeVersion(for: "sentry"))`
  public static func installedBundledThemeVersion(for themeName: String) -> String {
    "\(keyPrefix)theme.installedVersion.\(themeName)"
  }

  // MARK: - Migration

  /// Legacy keys mapping for migration
  private static let legacyKeyMappings: [String: String] = [
    "CLISessionsShowLastMessage": showLastMessage,
    "CLISessionsApprovalTimeout": approvalTimeout,
    "CLISessionsSelectedRepositories": selectedRepositories,
    "selectedTheme": selectedTheme,
    "customPrimaryHex": customPrimaryHex,
    "customSecondaryHex": customSecondaryHex,
    "customTertiaryHex": customTertiaryHex
  ]

  /// Migrates legacy UserDefaults keys to namespaced keys
  ///
  /// Call this once during app launch to migrate existing settings.
  /// The migration is idempotent - it only copies values if the new key doesn't exist.
  ///
  /// ```swift
  /// // In your App's init or onAppear
  /// AgentPiDefaults.migrateIfNeeded()
  /// ```
  public static func migrateIfNeeded() {
    let defaults = UserDefaults.standard
    let migrationKey = "\(keyPrefix)migration.completed.v2"

    // Skip if already migrated
    guard !defaults.bool(forKey: migrationKey) else { return }

    for (legacyKey, newKey) in legacyKeyMappings {
      // Only migrate if legacy key exists and new key doesn't
      if defaults.object(forKey: legacyKey) != nil && defaults.object(forKey: newKey) == nil {
        if let value = defaults.object(forKey: legacyKey) {
          defaults.set(value, forKey: newKey)
        }
      }
    }

    for oldPrefix in legacyPrefixedNamespaces {
      guard oldPrefix != keyPrefix else { continue }
      migratePrefixedKeys(from: oldPrefix, defaults: defaults)
    }

    defaults.set(true, forKey: migrationKey)
  }

  private static func migratePrefixedKeys(from oldPrefix: String, defaults: UserDefaults) {
    let legacyKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(oldPrefix) }
    for oldKey in legacyKeys {
      let suffix = String(oldKey.dropFirst(oldPrefix.count))
      let newKey = "\(keyPrefix)\(suffix)"
      guard defaults.object(forKey: newKey) == nil else { continue }
      guard let value = defaults.object(forKey: oldKey) else { continue }
      defaults.set(value, forKey: newKey)
    }
  }
}
