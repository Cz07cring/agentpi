//
//  AgentPiProvider.swift
//  AgentPi
//
//  Central service provider for AgentPi
//

import Foundation
import ClaudeCodeSDK
import os

/// Central service provider that manages all AgentPi services
///
/// `AgentPiProvider` provides lazy initialization of services and a single
/// factory for `ClaudeCodeClient` instances. Use this instead of manually
/// creating and wiring services.
///
/// ## Example
/// ```swift
/// @State private var provider = AgentPiProvider()
///
/// var body: some Scene {
///   WindowGroup {
///     AgentPiSessionsView()
///       .agentPi(provider)
///   }
/// }
/// ```
@MainActor
public final class AgentPiProvider {

  // MARK: - Configuration

  /// The configuration used by this provider
  public let configuration: AgentPiConfiguration

  // MARK: - Lazy Services

  /// Monitor service for tracking CLI sessions
  public private(set) lazy var monitorService: CLISessionMonitorService = {
    CLISessionMonitorService(claudeDataPath: configuration.claudeDataPath, metadataStore: metadataStore)
  }()

  /// Monitor service for tracking Codex sessions
  public private(set) lazy var codexMonitorService: CodexSessionMonitorService = {
    CodexSessionMonitorService(codexDataPath: configuration.codexDataPath, metadataStore: metadataStore)
  }()

  /// Monitor service for tracking AgentPi sessions
  public private(set) lazy var piMonitorService: CodexSessionMonitorService = {
    CodexSessionMonitorService(codexDataPath: configuration.piDataPath, metadataStore: metadataStore)
  }()

  /// Git worktree service for branch/worktree operations
  public private(set) lazy var gitService: GitWorktreeService = {
    GitWorktreeService()
  }()

  /// Global stats service for Claude usage metrics
  public private(set) lazy var statsService: GlobalStatsService = {
    GlobalStatsService(claudePath: configuration.claudeDataPath)
  }()

  /// Global stats service for Codex usage metrics
  public private(set) lazy var codexStatsService: CodexGlobalStatsService = {
    CodexGlobalStatsService(codexPath: configuration.codexDataPath)
  }()

  /// Global stats service for AgentPi usage metrics
  public private(set) lazy var piStatsService: CodexGlobalStatsService = {
    CodexGlobalStatsService(codexPath: configuration.piDataPath)
  }()

  /// Codex file watcher for real-time monitoring
  private lazy var codexFileWatcher: CodexSessionFileWatcher = {
    CodexSessionFileWatcher(codexPath: configuration.codexDataPath)
  }()

  /// AgentPi file watcher for real-time monitoring
  private lazy var piFileWatcher: CodexSessionFileWatcher = {
    CodexSessionFileWatcher(codexPath: configuration.piDataPath)
  }()

  /// Claude file watcher for real-time monitoring
  private lazy var claudeFileWatcher: SessionFileWatcher = {
    SessionFileWatcher(claudePath: configuration.claudeDataPath)
  }()

  /// Claude search service
  private lazy var claudeSearchService: GlobalSearchService = {
    GlobalSearchService(claudeDataPath: configuration.claudeDataPath)
  }()

  /// Codex search service
  private lazy var codexSearchService: CodexSearchService = {
    CodexSearchService(codexDataPath: configuration.codexDataPath)
  }()

  /// AgentPi search service
  private lazy var piSearchService: CodexSearchService = {
    CodexSearchService(codexDataPath: configuration.piDataPath)
  }()

  /// Display settings for stats visualization
  public private(set) lazy var displaySettings: StatsDisplaySettings = {
    StatsDisplaySettings(configuration.statsDisplayMode)
  }()

  /// Claude Code client for SDK communication
  public private(set) lazy var claudeClient: (any ClaudeCode)? = {
    createClaudeClient()
  }()

  /// Session metadata store for user-provided session names
  public private(set) lazy var metadataStore: SessionMetadataStore? = {
    do {
      return try SessionMetadataStore()
    } catch {
      AppLogger.session.error("Failed to create SessionMetadataStore: \(error.localizedDescription)")
      return nil
    }
  }()

  // MARK: - Theme Management

  /// Theme manager for YAML and built-in themes
  public private(set) lazy var themeManager: ThemeManager = {
    ThemeManager()
  }()

  // MARK: - View Models

  /// Claude sessions view model - created lazily and cached
  public private(set) lazy var claudeSessionsViewModel: CLISessionsViewModel = {
    makeSessionsViewModel(providerKind: .claude)
  }()

  /// Codex sessions view model - created lazily and cached
  public private(set) lazy var codexSessionsViewModel: CLISessionsViewModel = {
    makeSessionsViewModel(providerKind: .codex)
  }()

  /// AgentPi sessions view model - created lazily and cached
  public private(set) lazy var piSessionsViewModel: CLISessionsViewModel = {
    makeSessionsViewModel(providerKind: .pi)
  }()

  /// Backwards-compatible default sessions view model (Claude)
  public private(set) lazy var sessionsViewModel: CLISessionsViewModel = {
    claudeSessionsViewModel
  }()

  /// Intelligence view model - created lazily and cached
  public private(set) lazy var intelligenceViewModel: IntelligenceViewModel = {
    IntelligenceViewModel(claudeClient: claudeClient)
  }()

  // MARK: - Initialization

  /// Creates a provider with the specified configuration
  /// - Parameter configuration: Configuration for services. Defaults to `.default`
  public init(configuration: AgentPiConfiguration = .default) {
    self.configuration = configuration

    // Persist developer-provided commands to UserDefaults
    let defaults = UserDefaults.standard

    // Claude command: if developer provided non-default, lock it
    if configuration.cliCommand != "claude" {
      defaults.set(configuration.cliCommand, forKey: AgentPiDefaults.claudeCommand)
      defaults.set(true, forKey: AgentPiDefaults.claudeCommandLockedByDeveloper)
    } else if defaults.string(forKey: AgentPiDefaults.claudeCommand) == nil {
      // Set default if not already set by user
      defaults.set("claude", forKey: AgentPiDefaults.claudeCommand)
    }

    // Codex command: same logic
    if configuration.codexCommand != "codex" {
      defaults.set(configuration.codexCommand, forKey: AgentPiDefaults.codexCommand)
      defaults.set(true, forKey: AgentPiDefaults.codexCommandLockedByDeveloper)
    } else if defaults.string(forKey: AgentPiDefaults.codexCommand) == nil {
      defaults.set("codex", forKey: AgentPiDefaults.codexCommand)
    }

    // AgentPi command: migrate from previous codex key if needed.
    let legacyPiCommand = defaults.string(forKey: AgentPiDefaults.codexCommand)
    if configuration.piCommand != "pi" {
      defaults.set(configuration.piCommand, forKey: AgentPiDefaults.piCommand)
      defaults.set(true, forKey: AgentPiDefaults.piCommandLockedByDeveloper)
    } else if defaults.string(forKey: AgentPiDefaults.piCommand) == nil {
      if let legacyPiCommand, legacyPiCommand == "pi" {
        defaults.set(legacyPiCommand, forKey: AgentPiDefaults.piCommand)
        if configuration.codexCommand == "codex" {
          defaults.set("codex", forKey: AgentPiDefaults.codexCommand)
        }
      } else {
        defaults.set("pi", forKey: AgentPiDefaults.piCommand)
      }
    }

    CommandTemplateService.shared.ensureInitialized(
      claudeCommand: defaults.string(forKey: AgentPiDefaults.claudeCommand) ?? configuration.cliCommand,
      codexCommand: defaults.string(forKey: AgentPiDefaults.codexCommand) ?? configuration.codexCommand,
      piCommand: defaults.string(forKey: AgentPiDefaults.piCommand) ?? configuration.piCommand,
      mobileRelayClaudeCommand: defaults.string(forKey: AgentPiDefaults.mobileRelayClaudeCommand),
      mobileRelayCodexCommand: defaults.string(forKey: AgentPiDefaults.mobileRelayCodexCommand),
      mobileRelayPiCommand: defaults.string(forKey: AgentPiDefaults.mobileRelayPiCommand)
    )
  }

  /// Creates a provider with default configuration
  public convenience init() {
    self.init(configuration: .default)
  }

  // MARK: - Claude Client Factory

  /// Creates a configured ClaudeCodeClient instance
  /// - Returns: A configured client, or nil if creation fails
  private func createClaudeClient() -> (any ClaudeCode)? {
    do {
      var config = ClaudeCodeConfiguration.withNvmSupport()
      config.command = configuration.cliCommand
      config.enableDebugLogging = configuration.enableDebugLogging

      let homeDir = NSHomeDirectory()

      // Add local Claude installation path (highest priority)
      let localClaudePath = "\(homeDir)/.claude/local"
      if FileManager.default.fileExists(atPath: localClaudePath) {
        config.additionalPaths.insert(localClaudePath, at: 0)
      }

      // Add configured additional paths
      for path in configuration.additionalCLIPaths {
        if !config.additionalPaths.contains(path) {
          config.additionalPaths.append(path)
        }
      }

      // Add common development tool paths
      let defaultPaths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "\(homeDir)/.bun/bin",
        "\(homeDir)/.deno/bin",
        "\(homeDir)/.cargo/bin",
        "\(homeDir)/.local/bin"
      ]

      for path in defaultPaths {
        if !config.additionalPaths.contains(path) {
          config.additionalPaths.append(path)
        }
      }

      return try ClaudeCodeClient(configuration: config)
    } catch {
      AppLogger.session.error("Failed to create ClaudeCodeClient: \(error.localizedDescription)")
      return nil
    }
  }

  // MARK: - Sessions ViewModel Factory

  private func makeSessionsViewModel(providerKind: SessionProviderKind) -> CLISessionsViewModel {
    let cliConfiguration: CLICommandConfiguration
    let defaults = UserDefaults.standard
    switch providerKind {
    case .claude:
      let command = defaults.string(forKey: AgentPiDefaults.claudeCommand)
        ?? claudeClient?.configuration.command
        ?? configuration.cliCommand
      let paths = claudeClient?.configuration.additionalPaths ?? configuration.additionalCLIPaths
      cliConfiguration = CLICommandConfiguration(command: command, additionalPaths: paths, mode: .claude)
    case .codex:
      let userCommand = defaults.string(forKey: AgentPiDefaults.codexCommand) ?? configuration.codexCommand
      // Store the user's configured command string as-is (e.g. "airchat codex")
      // Executable resolution happens at launch time using executableName
      cliConfiguration = CLICommandConfiguration(command: userCommand, additionalPaths: configuration.additionalCLIPaths, mode: .codex)
    case .pi:
      let userCommand = defaults.string(forKey: AgentPiDefaults.piCommand) ?? configuration.piCommand
      cliConfiguration = CLICommandConfiguration(command: userCommand, additionalPaths: configuration.additionalCLIPaths, mode: .pi)
    }

    let selectedMonitor: any SessionMonitorServiceProtocol = {
      switch providerKind {
      case .claude: return monitorService
      case .codex: return codexMonitorService
      case .pi: return piMonitorService
      }
    }()

    let selectedWatcher: any SessionFileWatcherProtocol = {
      switch providerKind {
      case .claude: return claudeFileWatcher
      case .codex: return codexFileWatcher
      case .pi: return piFileWatcher
      }
    }()

    let selectedSearch: (any SessionSearchServiceProtocol)? = {
      switch providerKind {
      case .claude: return claudeSearchService
      case .codex: return codexSearchService
      case .pi: return piSearchService
      }
    }()

    return CLISessionsViewModel(
      monitorService: selectedMonitor,
      fileWatcher: selectedWatcher,
      searchService: selectedSearch,
      cliConfiguration: cliConfiguration,
      providerKind: providerKind,
      codexDataPath: providerKind == .codex
        ? configuration.codexDataPath
        : (providerKind == .pi ? configuration.piDataPath : nil),
      claudeClient: providerKind == .claude ? claudeClient : nil,
      metadataStore: metadataStore
    )
  }

  // MARK: - Public Factory Methods

  /// Creates a new Claude client with the provider's configuration
  /// - Returns: A new ClaudeCodeClient, or nil if creation fails
  ///
  /// Use this when you need a fresh client instance rather than the shared one.
  public func makeClaudeClient() -> (any ClaudeCode)? {
    createClaudeClient()
  }

  // MARK: - App Lifecycle

  /// Cleans up orphaned Claude processes from previous runs.
  /// Call this on app launch to terminate any Claude processes that were orphaned
  /// when the app crashed or was force-quit.
  public func cleanupOrphanedProcesses() {
    TerminalProcessRegistry.shared.cleanupRegisteredProcesses()
  }

  /// Terminates all active terminal processes.
  /// Call this on app termination to clean up all running Claude sessions.
  public func terminateAllTerminals() {
    let allTerminals = claudeSessionsViewModel.activeTerminals.merging(
      codexSessionsViewModel.activeTerminals,
      uniquingKeysWith: { first, _ in first }
    ).merging(
      piSessionsViewModel.activeTerminals,
      uniquingKeysWith: { first, _ in first }
    )

    for (key, terminal) in allTerminals {
      AppLogger.session.info("Terminating terminal for key: \(key)")
      terminal.terminateProcess()
    }
  }
}
