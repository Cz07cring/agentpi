//
//  CLIDetectionService.swift
//  AgentPi
//
//  Detects installed CLI tools by checking executables and data directories.
//

import Foundation

/// Service for detecting installed CLI tools
public struct CLIDetectionService {

  public enum AvailabilityStatus: String, Sendable {
    case available
    case missing
    case misconfigured

    public var isLaunchable: Bool {
      self == .available
    }
  }

  public struct ProviderAvailability: Sendable {
    public let provider: SessionProviderKind
    public let isExecutableFound: Bool
    public let hasDataDirectory: Bool
    public let status: AvailabilityStatus
    public let installURL: URL

    public var isLaunchable: Bool {
      status.isLaunchable
    }
  }

  /// Result of CLI detection
  public struct DetectionResult {
    public let claudeInstalled: Bool
    public let codexInstalled: Bool
    public let piInstalled: Bool

    /// At least one CLI is installed
    public var hasAnyCLI: Bool {
      claudeInstalled || codexInstalled || piInstalled
    }
  }

  /// Checks if Claude CLI is installed
  /// Detection checks: executable path
  /// - Parameter additionalPaths: Additional paths to search for executable
  /// - Returns: true if Claude CLI is detected
  public static func isClaudeInstalled(additionalPaths: [String]? = nil) -> Bool {
    detectProviderAvailability(provider: .claude, additionalPaths: additionalPaths).isLaunchable
  }

  /// Checks if Codex CLI is installed
  /// Detection checks: executable path
  /// - Parameter additionalPaths: Additional paths to search for executable
  /// - Returns: true if Codex CLI is detected
  public static func isCodexInstalled(additionalPaths: [String]? = nil) -> Bool {
    detectProviderAvailability(provider: .codex, additionalPaths: additionalPaths).isLaunchable
  }

  /// Checks if AgentPi CLI is installed
  /// Detection checks: executable path
  /// - Parameter additionalPaths: Additional paths to search for executable
  /// - Returns: true if AgentPi CLI is detected
  public static func isPiInstalled(additionalPaths: [String]? = nil) -> Bool {
    detectProviderAvailability(provider: .pi, additionalPaths: additionalPaths).isLaunchable
  }

  public static func providerInstallURL(for provider: SessionProviderKind) -> URL {
    switch provider {
    case .claude:
      return URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!
    case .codex:
      return URL(string: "https://developers.openai.com/codex/cli")!
    case .pi:
      return URL(string: "https://github.com/badlogic/pi-mono")!
    }
  }

  public static func detectProviderAvailability(
    provider: SessionProviderKind,
    additionalPaths: [String]? = nil
  ) -> ProviderAvailability {
    let executableFound = detectExecutable(provider: provider, additionalPaths: additionalPaths)
    let hasDataDirectory = detectDataDirectory(provider: provider)

    let status: AvailabilityStatus
    if executableFound {
      status = .available
    } else if hasDataDirectory {
      status = .misconfigured
    } else {
      status = .missing
    }

    return ProviderAvailability(
      provider: provider,
      isExecutableFound: executableFound,
      hasDataDirectory: hasDataDirectory,
      status: status,
      installURL: providerInstallURL(for: provider)
    )
  }

  public static func detectProviderAvailabilities(
    providers: [SessionProviderKind],
    additionalPaths: [String]? = nil
  ) -> [ProviderAvailability] {
    providers.map { detectProviderAvailability(provider: $0, additionalPaths: additionalPaths) }
  }

  /// Detects which CLI tools are installed
  /// - Parameter additionalPaths: Additional paths to search
  /// - Returns: Detection result indicating which CLIs are found
  public static func detectInstalledCLIs(additionalPaths: [String]? = nil) -> DetectionResult {
    return DetectionResult(
      claudeInstalled: isClaudeInstalled(additionalPaths: additionalPaths),
      codexInstalled: isCodexInstalled(additionalPaths: additionalPaths),
      piInstalled: isPiInstalled(additionalPaths: additionalPaths)
    )
  }

  private static func detectExecutable(
    provider: SessionProviderKind,
    additionalPaths: [String]?
  ) -> Bool {
    switch provider {
    case .claude:
      let configuredCommand = UserDefaults.standard.string(forKey: AgentPiDefaults.claudeCommand) ?? "claude"
      let executable = executableName(from: configuredCommand)
      return TerminalLauncher.findClaudeExecutable(command: executable, additionalPaths: additionalPaths) != nil
    case .codex:
      let configuredCommand = UserDefaults.standard.string(forKey: AgentPiDefaults.codexCommand) ?? "codex"
      let executable = executableName(from: configuredCommand)
      return TerminalLauncher.findCodexExecutable(command: executable, additionalPaths: additionalPaths) != nil
    case .pi:
      let configuredCommand = UserDefaults.standard.string(forKey: AgentPiDefaults.piCommand) ?? "pi"
      let executable = executableName(from: configuredCommand)
      return TerminalLauncher.findCodexExecutable(command: executable, additionalPaths: additionalPaths) != nil
    }
  }

  private static func detectDataDirectory(provider: SessionProviderKind) -> Bool {
    let fileManager = FileManager.default
    let homeDir = NSHomeDirectory()

    switch provider {
    case .claude:
      return fileManager.fileExists(atPath: "\(homeDir)/.claude")
    case .codex:
      return fileManager.fileExists(atPath: "\(homeDir)/.codex")
    case .pi:
      let envPath = ProcessInfo.processInfo.environment["PI_CODING_AGENT_DIR"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let candidates = [
        envPath,
        "\(homeDir)/.pi/agent",
        "\(homeDir)/.agentpi"
      ].compactMap { $0 }
      return candidates.contains { fileManager.fileExists(atPath: $0) }
    }
  }

  private static func executableName(from command: String) -> String {
    let raw = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return command }
    return String(raw.split(separator: " ", maxSplits: 1).first ?? Substring(raw))
  }
}
