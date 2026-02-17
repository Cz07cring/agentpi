//
//  AgentPiConfiguration.swift
//  AgentPi
//
//  Configuration for AgentPi services and providers
//

import Foundation

/// Configuration for AgentPi services
///
/// Use this to customize behavior when initializing `AgentPiProvider`.
///
/// ## Example
/// ```swift
/// var config = AgentPiConfiguration.default
/// config.enableDebugLogging = true
/// let provider = AgentPiProvider(configuration: config)
/// ```
public struct AgentPiConfiguration: Sendable {

  /// Path to Claude data directory (default: ~/.claude)
  public var claudeDataPath: String

  /// Path to Codex data directory (default: ~/.codex)
  public var codexDataPath: String

  /// Path to AgentPi data directory (default: PI_CODING_AGENT_DIR or ~/.pi/agent)
  public var piDataPath: String

  /// Enable debug logging for troubleshooting
  public var enableDebugLogging: Bool

  /// Additional paths to search for Claude CLI
  /// These are added to the PATH when launching Claude processes
  public var additionalCLIPaths: [String]

  /// Display mode for stats (menu bar or popover)
  public var statsDisplayMode: StatsDisplayMode

  /// The CLI command name to use (default: "claude")
  /// Companies can configure this for white-labeling (e.g., "acme" instead of "claude")
  public var cliCommand: String

  /// The Codex CLI command name to use (default: "codex")
  /// Companies can configure this for white-labeling
  public var codexCommand: String

  /// The AgentPi CLI command name to use (default: "pi")
  public var piCommand: String

  /// Session provider to use (Claude or Codex)
  public var sessionProvider: SessionProviderKind

  /// Resolves the default AgentPi data directory.
  /// Priority: PI_CODING_AGENT_DIR -> existing ~/.pi/agent -> existing ~/.agentpi -> ~/.pi/agent
  public static func defaultPiDataPath() -> String {
    let envPath = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"]?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let envPath, !envPath.isEmpty {
      return NSString(string: envPath).expandingTildeInPath
    }

    let homeDir = NSHomeDirectory()
    let candidates = [
      "\(homeDir)/.pi/agent",
      "\(homeDir)/.agentpi"
    ]

    for candidate in candidates where FileManager.default.fileExists(atPath: candidate) {
      return candidate
    }

    return "\(homeDir)/.pi/agent"
  }

  /// Resolves the default Codex data directory.
  public static func defaultCodexDataPath() -> String {
    let homeDir = NSHomeDirectory()
    return "\(homeDir)/.codex"
  }

  /// Creates a configuration with custom values
  public init(
    claudeDataPath: String = "~/.claude",
    codexDataPath: String = AgentPiConfiguration.defaultCodexDataPath(),
    piDataPath: String = AgentPiConfiguration.defaultPiDataPath(),
    enableDebugLogging: Bool = false,
    additionalCLIPaths: [String] = [],
    statsDisplayMode: StatsDisplayMode = .menuBar,
    cliCommand: String = "claude",
    codexCommand: String = "codex",
    piCommand: String = "pi",
    sessionProvider: SessionProviderKind = .pi
  ) {
    let expanded = NSString(string: claudeDataPath).expandingTildeInPath
    self.claudeDataPath = expanded
    self.codexDataPath = NSString(string: codexDataPath).expandingTildeInPath
    self.piDataPath = NSString(string: piDataPath).expandingTildeInPath
    self.enableDebugLogging = enableDebugLogging
    self.additionalCLIPaths = additionalCLIPaths
    self.statsDisplayMode = statsDisplayMode
    self.cliCommand = cliCommand
    self.codexCommand = codexCommand
    self.piCommand = piCommand
    self.sessionProvider = sessionProvider
  }

  /// Default configuration with sensible defaults
  public static var `default`: AgentPiConfiguration {
    AgentPiConfiguration()
  }

  /// Configuration with common development tool paths included
  public static var withDevPaths: AgentPiConfiguration {
    let homeDir = NSHomeDirectory()
    return AgentPiConfiguration(
      additionalCLIPaths: [
        "\(homeDir)/.claude/local",
        "\(homeDir)/.codex/local",
        "\(homeDir)/.codex/bin",
        "\(homeDir)/.pi/agent/bin",
        "\(homeDir)/.agentpi/bin",
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "\(homeDir)/.bun/bin",
        "\(homeDir)/.deno/bin",
        "\(homeDir)/.cargo/bin",
        "\(homeDir)/.local/bin"
      ]
    )
  }
}
