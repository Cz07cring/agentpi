import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct CLICommandConfigurationTests {
  @Test("tokenize command keeps quoted segments")
  func tokenizeCommandKeepsQuotedSegments() {
    let tokens = CLICommandConfiguration.tokenizeCommand("\"/opt/homebrew/bin/happy\" codex --profile \"mobile link\"")
    #expect(tokens == ["/opt/homebrew/bin/happy", "codex", "--profile", "mobile link"])
  }

  @Test("codex mode resumes with resume subcommand")
  func codexModeUsesResumeSubcommand() {
    let config = CLICommandConfiguration(command: "codex", mode: .codex)
    let args = config.argumentsForSession(
      sessionId: "session-123",
      sessionFilePath: "/tmp/ignored.jsonl",
      prompt: "hello"
    )
    #expect(args == ["resume", "session-123", "hello"])
  }

  @Test("happy codex wrapper keeps prefix and uses resume")
  func codexWrapperUsesResume() {
    let config = CLICommandConfiguration(command: "happy codex", mode: .codex)
    let args = config.argumentsForSession(
      sessionId: "session-123",
      prompt: nil
    )
    #expect(args == ["codex", "resume", "session-123"])
  }

  @Test("detects happy codex relay command")
  func detectsHappyCodexRelayCommand() {
    #expect(CLICommandConfiguration(command: "happy codex", mode: .codex).isHappyCodexRelayCommand)
    #expect(CLICommandConfiguration(command: "/opt/homebrew/bin/happy codex", mode: .codex).isHappyCodexRelayCommand)
    #expect(CLICommandConfiguration(command: "codex", mode: .codex).isHappyCodexRelayCommand == false)
  }

  @Test("detects happy pi relay command")
  func detectsHappyPiRelayCommand() {
    #expect(CLICommandConfiguration(command: "happy pi", mode: .pi).isHappyPiRelayCommand)
    #expect(CLICommandConfiguration(command: "happy agentpi", mode: .pi).isHappyPiRelayCommand)
    #expect(CLICommandConfiguration(command: "pi", mode: .pi).isHappyPiRelayCommand == false)
  }

  @Test("detects happy claude relay command")
  func detectsHappyClaudeRelayCommand() {
    #expect(CLICommandConfiguration(command: "happy", mode: .claude).isHappyClaudeRelayCommand)
    #expect(CLICommandConfiguration(command: "happy claude", mode: .claude).isHappyClaudeRelayCommand)
    #expect(CLICommandConfiguration(command: "claude", mode: .claude).isHappyClaudeRelayCommand == false)
  }

  @Test("pi mode uses --session for native pi command")
  func piModeUsesSessionFileForNativePi() {
    let config = CLICommandConfiguration(command: "pi", mode: .pi)
    let args = config.argumentsForSession(
      sessionId: "session-123",
      sessionFilePath: "/tmp/session.jsonl",
      prompt: "hello"
    )
    #expect(args == ["--session", "/tmp/session.jsonl", "hello"])
  }

  @Test("pi mode falls back safely for non-pi wrapper")
  func piModeWithoutPiTokenDoesNotInjectPiFlags() {
    let config = CLICommandConfiguration(command: "happy", mode: .pi)
    let args = config.argumentsForSession(
      sessionId: "session-123",
      sessionFilePath: "/tmp/session.jsonl",
      prompt: "hello"
    )
    #expect(args == ["hello"])
  }

  @Test("pi wrapper with explicit subcommand pi keeps session flags")
  func piWrapperWithSubcommandStillUsesPiSessionFlags() {
    let config = CLICommandConfiguration(command: "happy pi", mode: .pi)
    let args = config.argumentsForSession(
      sessionId: "session-123",
      sessionFilePath: "/tmp/session.jsonl",
      prompt: nil
    )
    #expect(args == ["pi", "--session", "/tmp/session.jsonl"])
  }

  @Test("template arguments render placeholders as positional tokens")
  func templateArgumentsRenderPlaceholders() {
    let config = CLICommandConfiguration(command: "claude", mode: .claude)
    let template = AgentCommandTemplateV1(
      provider: .claude,
      name: "Batch",
      intent: .batchRun,
      executionKind: .batchRun,
      executable: "claude",
      argsTemplate: ["-p", "{{prompt}}", "--project", "{{project_path}}", "--branch", "{{branch}}"]
    )
    let args = config.argumentsForTemplate(
      template,
      context: .init(
        prompt: "hello world",
        projectPath: "/tmp/repo",
        branch: "main"
      )
    )
    #expect(args == ["-p", "hello world", "--project", "/tmp/repo", "--branch", "main"])
  }

  @Test("codex template arguments drop deprecated no-alt-screen")
  func codexTemplateDropsDeprecatedNoAltScreen() {
    let config = CLICommandConfiguration(command: "happy codex", mode: .codex)
    let template = AgentCommandTemplateV1(
      provider: .codex,
      name: "Legacy Codex Session",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "codex",
      argsTemplate: ["--no-alt-screen", "{{prompt}}"]
    )

    let args = config.argumentsForTemplate(
      template,
      context: .init(prompt: "hello")
    )
    #expect(args == ["codex", "hello"])
  }

  @Test("template arguments render mobile handoff placeholders")
  func templateArgumentsRenderMobileHandoffPlaceholders() {
    let config = CLICommandConfiguration(command: "happy codex", mode: .codex)
    let template = AgentCommandTemplateV1(
      provider: .codex,
      name: "Mobile Relay",
      intent: .mobileRelay,
      executionKind: .externalTerminal,
      executable: "happy codex",
      argsTemplate: ["--handoff", "{{handoff_jsonl}}", "--summary", "{{handoff_md}}", "--source", "{{source_provider}}", "--target", "{{target_provider}}"]
    )
    let args = config.argumentsForTemplate(
      template,
      context: .init(
        handoffJSONLPath: "/tmp/handoff.jsonl",
        handoffMarkdownPath: "/tmp/handoff.md",
        sourceProvider: "claude",
        targetProvider: "codex"
      )
    )
    #expect(args == ["codex", "--handoff", "/tmp/handoff.jsonl", "--summary", "/tmp/handoff.md", "--source", "claude", "--target", "codex"])
  }
}
