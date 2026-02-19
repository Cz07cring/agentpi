//
//  CLICommandConfiguration.swift
//  AgentPi
//
//  Provider-agnostic CLI command configuration for embedded terminals.
//

import Foundation

public enum CLICommandMode: String, Codable, Sendable {
  case claude
  case codex
  case pi
}

public struct CLICommandConfiguration: Codable, Sendable {
  public struct TemplateRenderContext: Sendable {
    public var prompt: String?
    public var sessionId: String?
    public var sessionFilePath: String?
    public var projectPath: String?
    public var branch: String?
    public var handoffJSONLPath: String?
    public var handoffMarkdownPath: String?
    public var sourceProvider: String?
    public var targetProvider: String?

    public init(
      prompt: String? = nil,
      sessionId: String? = nil,
      sessionFilePath: String? = nil,
      projectPath: String? = nil,
      branch: String? = nil,
      handoffJSONLPath: String? = nil,
      handoffMarkdownPath: String? = nil,
      sourceProvider: String? = nil,
      targetProvider: String? = nil
    ) {
      self.prompt = prompt
      self.sessionId = sessionId
      self.sessionFilePath = sessionFilePath
      self.projectPath = projectPath
      self.branch = branch
      self.handoffJSONLPath = handoffJSONLPath
      self.handoffMarkdownPath = handoffMarkdownPath
      self.sourceProvider = sourceProvider
      self.targetProvider = targetProvider
    }
  }

  public var command: String
  public var additionalPaths: [String]
  public var mode: CLICommandMode

  public init(
    command: String,
    additionalPaths: [String] = [],
    mode: CLICommandMode
  ) {
    self.command = command
    self.additionalPaths = additionalPaths
    self.mode = mode
  }

  /// The executable name (first word of command). e.g. "airchat" from "airchat codex"
  public var executableName: String {
    commandTokens.first ?? command.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Subcommand arguments (remaining words after executable). e.g. ["codex"] from "airchat codex"
  public var subcommandArgs: [String] {
    guard commandTokens.count > 1 else { return [] }
    return Array(commandTokens.dropFirst())
  }

  /// Shell-like tokenization that preserves quoted segments.
  public var commandTokens: [String] {
    Self.tokenizeCommand(command)
  }

  /// `happy codex` launches Happy's relay UI (waiting for mobile messages),
  /// not Codex's local interactive REPL.
  public var isHappyCodexRelayCommand: Bool {
    guard mode == .codex else { return false }
    let tokens = commandTokens
    guard isHappyRelayExecutable(tokens: tokens) else { return false }
    return tokens.dropFirst().contains { $0.caseInsensitiveCompare("codex") == .orderedSame }
  }

  /// `happy pi` launches Happy relay and is not compatible with local `pi --session` args.
  public var isHappyPiRelayCommand: Bool {
    guard mode == .pi else { return false }
    let tokens = commandTokens
    guard isHappyRelayExecutable(tokens: tokens) else { return false }
    return tokens.dropFirst().contains {
      $0.caseInsensitiveCompare("pi") == .orderedSame
      || $0.caseInsensitiveCompare("agentpi") == .orderedSame
    }
  }

  /// `happy` (or `happy claude`) relay should not be used for embedded interactive sessions.
  public var isHappyClaudeRelayCommand: Bool {
    guard mode == .claude else { return false }
    let tokens = commandTokens
    guard isHappyRelayExecutable(tokens: tokens) else { return false }
    let subcommands = tokens.dropFirst()
    if subcommands.isEmpty { return true }
    return subcommands.contains {
      $0.caseInsensitiveCompare("claude") == .orderedSame
      || $0.caseInsensitiveCompare("claude-code") == .orderedSame
    }
  }

  public static var claudeDefault: CLICommandConfiguration {
    CLICommandConfiguration(command: "claude", additionalPaths: [], mode: .claude)
  }

  public static var codexDefault: CLICommandConfiguration {
    CLICommandConfiguration(command: "codex", additionalPaths: [], mode: .codex)
  }

  public static var piDefault: CLICommandConfiguration {
    CLICommandConfiguration(command: "pi", additionalPaths: [], mode: .pi)
  }

  public func argumentsForSession(
    sessionId: String?,
    sessionFilePath: String? = nil,
    prompt: String?,
    dangerouslySkipPermissions: Bool = false
  ) -> [String] {
    let prefix = subcommandArgs

    switch mode {
    case .claude:
      var args: [String] = []

      // Add flag only for NEW sessions (not resume)
      if dangerouslySkipPermissions && (sessionId == nil || sessionId?.isEmpty == true || sessionId?.hasPrefix("pending-") == true) {
        args.append("--dangerously-skip-permissions")
      }

      if let sessionId, !sessionId.isEmpty, !sessionId.hasPrefix("pending-") {
        if let prompt, !prompt.isEmpty {
          return prefix + args + ["-r", sessionId, prompt]
        }
        return prefix + args + ["-r", sessionId]
      }
      if let prompt, !prompt.isEmpty {
        return prefix + args + [prompt]
      }
      return prefix + args

    case .codex:
      // Codex CLI resumes with `resume <sessionId>` instead of --session/--continue flags.
      if supportsCodexResumeArguments,
        let sessionId,
        !sessionId.isEmpty,
        !sessionId.hasPrefix("pending-")
      {
        if let prompt, !prompt.isEmpty {
          return prefix + ["resume", sessionId, prompt]
        }
        return prefix + ["resume", sessionId]
      }

      if let prompt, !prompt.isEmpty {
        return prefix + [prompt]
      }
      return prefix

    case .pi:
      // AgentPi/pi: prefer explicit session file when available.
      if supportsPiSessionArguments, let sessionFilePath, !sessionFilePath.isEmpty {
        if let prompt, !prompt.isEmpty {
          return prefix + ["--session", sessionFilePath, prompt]
        }
        return prefix + ["--session", sessionFilePath]
      }

      // Fallback for existing sessions when file path is unknown.
      if supportsPiSessionArguments,
        let sessionId,
        !sessionId.isEmpty,
        !sessionId.hasPrefix("pending-")
      {
        if let prompt, !prompt.isEmpty {
          return prefix + ["--continue", prompt]
        }
        return prefix + ["--continue"]
      }

      // Start a new AgentPi session with optional prompt as positional argument.
      if let prompt, !prompt.isEmpty {
        return prefix + [prompt]
      }
      return prefix
    }
  }

  private var supportsCodexResumeArguments: Bool {
    commandTokens.contains { $0.caseInsensitiveCompare("codex") == .orderedSame }
  }

  private var supportsPiSessionArguments: Bool {
    commandTokens.contains { $0.caseInsensitiveCompare("pi") == .orderedSame }
  }

  static func tokenizeCommand(_ command: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    var inSingleQuote = false
    var inDoubleQuote = false
    var isEscaped = false

    for char in command {
      if isEscaped {
        current.append(char)
        isEscaped = false
        continue
      }

      if char == "\\" && !inSingleQuote {
        isEscaped = true
        continue
      }

      if char == "'" && !inDoubleQuote {
        inSingleQuote.toggle()
        continue
      }

      if char == "\"" && !inSingleQuote {
        inDoubleQuote.toggle()
        continue
      }

      if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
        if !current.isEmpty {
          tokens.append(current)
          current.removeAll(keepingCapacity: true)
        }
        continue
      }

      current.append(char)
    }

    if isEscaped {
      current.append("\\")
    }

    if !current.isEmpty {
      tokens.append(current)
    }

    return tokens
  }

  private func isHappyRelayExecutable(tokens: [String]) -> Bool {
    guard let first = tokens.first else { return false }
    return URL(fileURLWithPath: first).lastPathComponent.caseInsensitiveCompare("happy") == .orderedSame
  }

  public func argumentsForTemplate(
    _ template: AgentCommandTemplateV1,
    context: TemplateRenderContext
  ) -> [String] {
    let prefix = subcommandArgs
    let rendered = template.argsTemplate.compactMap { token in
      Self.renderTemplateToken(token, context: context)
    }
    var args = prefix + rendered
    if mode == .codex {
      // Removed in newer Codex/compat wrappers; keep legacy templates launchable.
      args.removeAll { $0.caseInsensitiveCompare("--no-alt-screen") == .orderedSame }
    }
    return args
  }

  private static func renderTemplateToken(
    _ token: String,
    context: TemplateRenderContext
  ) -> String? {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let promptValue = context.prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let sessionValue = context.sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let sessionFileValue = context.sessionFilePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let projectValue = context.projectPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let branchValue = context.branch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let handoffJSONLValue = context.handoffJSONLPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let handoffMarkdownValue = context.handoffMarkdownPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let sourceProviderValue = context.sourceProvider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let targetProviderValue = context.targetProvider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let replaced = trimmed
      .replacingOccurrences(of: "{{prompt}}", with: promptValue)
      .replacingOccurrences(of: "{{session_id}}", with: sessionValue)
      .replacingOccurrences(of: "{{session_file}}", with: sessionFileValue)
      .replacingOccurrences(of: "{{project_path}}", with: projectValue)
      .replacingOccurrences(of: "{{branch}}", with: branchValue)
      .replacingOccurrences(of: "{{handoff_jsonl}}", with: handoffJSONLValue)
      .replacingOccurrences(of: "{{handoff_md}}", with: handoffMarkdownValue)
      .replacingOccurrences(of: "{{source_provider}}", with: sourceProviderValue)
      .replacingOccurrences(of: "{{target_provider}}", with: targetProviderValue)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return replaced.isEmpty ? nil : replaced
  }
}
