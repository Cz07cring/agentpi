import Foundation
import Testing
@testable import AgentPiCore

@Suite(.serialized)
struct CommandTemplateServiceTests {
  @MainActor
  @Test("initialization injects builtins and migrates legacy commands")
  func initializationMigratesLegacyCommands() {
    let defaults = makeDefaults()
    let service = CommandTemplateService(defaults: defaults)

    service.ensureInitialized(
      claudeCommand: "happy claude",
      codexCommand: "happy codex",
      piCommand: "happy pi"
    )

    let templates = service.allTemplates()
    #expect(templates.contains(where: {
      $0.id == "legacy-claude-start" && $0.executable == "happy claude"
    }))
    #expect(templates.contains(where: {
      $0.id == "builtin-codex-batch-jsonl"
    }))
    #expect(templates.contains(where: {
      $0.id == "builtin-pi-batch-fast"
    }))
    #expect(service.defaultTemplate(for: .claude)?.id == "legacy-claude-start")
  }

  @MainActor
  @Test("deleting default template falls back to another enabled template")
  func deletingDefaultFallsBack() {
    let defaults = makeDefaults()
    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let currentDefault = service.defaultTemplate(for: .claude)
    #expect(currentDefault != nil)
    guard let currentDefault else { return }

    service.deleteTemplate(id: currentDefault.id)

    let newDefault = service.defaultTemplate(for: .claude)
    #expect(newDefault != nil)
    #expect(newDefault?.id != currentDefault.id)
  }

  @MainActor
  @Test("initialization includes builtin mobile relay templates")
  func initializationIncludesBuiltinMobileRelayTemplates() {
    let defaults = makeDefaults()
    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    #expect(service.templates(for: .claude, intent: .mobileRelay).contains(where: { $0.id == "builtin-claude-mobile-relay" }))
    #expect(service.templates(for: .codex, intent: .mobileRelay).contains(where: { $0.id == "builtin-codex-mobile-relay" }))
    #expect(service.templates(for: .pi, intent: .mobileRelay).contains(where: { $0.id == "builtin-pi-mobile-relay" }))
  }

  @MainActor
  @Test("legacy mobile relay commands migrate to templates")
  func legacyMobileRelayCommandsMigrateToTemplates() {
    let defaults = makeDefaults()
    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi",
      mobileRelayClaudeCommand: "happy claude-custom",
      mobileRelayCodexCommand: "happy codex-custom",
      mobileRelayPiCommand: "happy pi-custom"
    )

    let claudeMigrated = service.template(by: "migrated-claude-mobile-relay")
    let codexMigrated = service.template(by: "migrated-codex-mobile-relay")
    let piMigrated = service.template(by: "migrated-pi-mobile-relay")
    #expect(claudeMigrated?.intent == .mobileRelay)
    #expect(codexMigrated?.intent == .mobileRelay)
    #expect(piMigrated?.intent == .mobileRelay)
    #expect(claudeMigrated?.executable == "happy claude-custom")
  }

  @MainActor
  @Test("builtin pi rpc batch template is disabled by default")
  func builtinPiRPCBatchTemplateDisabledByDefault() {
    let defaults = makeDefaults()
    let service = CommandTemplateService(defaults: defaults)

    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let rpcTemplate = service.template(by: "builtin-pi-rpc-service")
    #expect(rpcTemplate != nil)
    #expect(rpcTemplate?.enabled == false)
  }

  @MainActor
  @Test("migration disables pre-existing enabled pi rpc batch template")
  func migrationDisablesPreexistingPiRPCBatchTemplate() throws {
    let defaults = makeDefaults()
    let now = Date()
    let legacyRPC = AgentCommandTemplateV1(
      id: "builtin-pi-rpc-service",
      provider: .pi,
      name: "RPC Service",
      intent: .batchRun,
      executionKind: .batchRun,
      executable: "pi",
      argsTemplate: ["--mode", "rpc"],
      enabled: true,
      isBuiltin: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now
    )
    let library = AgentCommandTemplateLibraryV1(templates: [legacyRPC])
    let data = try JSONEncoder().encode(library)
    defaults.set(data, forKey: AgentPiDefaults.commandTemplateLibrary)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let migrated = service.template(by: "builtin-pi-rpc-service")
    #expect(migrated != nil)
    #expect(migrated?.enabled == false)
  }

  @MainActor
  @Test("migration injects pi batch fast template for existing users")
  func migrationInjectsPiBatchFastTemplate() throws {
    let defaults = makeDefaults()
    let now = Date()
    let existingTemplate = AgentCommandTemplateV1(
      id: "legacy-pi-start",
      provider: .pi,
      name: "Legacy AgentPi",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "pi",
      argsTemplate: ["{{prompt}}"],
      enabled: true,
      isBuiltin: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now
    )
    let library = AgentCommandTemplateLibraryV1(templates: [existingTemplate])
    let data = try JSONEncoder().encode(library)
    defaults.set(data, forKey: AgentPiDefaults.commandTemplateLibrary)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let batchFast = service.template(by: "builtin-pi-batch-fast")
    #expect(batchFast != nil)
    #expect(batchFast?.intent == .batchRun)
    #expect(batchFast?.enabled == true)
  }

  @MainActor
  @Test("migration removes deprecated codex --no-alt-screen flag")
  func migrationRemovesDeprecatedCodexNoAltScreen() throws {
    let defaults = makeDefaults()
    let now = Date()
    let codexFast = AgentCommandTemplateV1(
      id: "builtin-codex-session-fast",
      provider: .codex,
      name: "Session Fast",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "codex",
      argsTemplate: ["--no-alt-screen", "{{prompt}}"],
      enabled: true,
      isBuiltin: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now
    )
    let codexAggressive = AgentCommandTemplateV1(
      id: "builtin-codex-session-aggressive",
      provider: .codex,
      name: "Session Aggressive",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "codex",
      argsTemplate: ["--full-auto", "--no-alt-screen", "{{prompt}}"],
      enabled: true,
      isBuiltin: true,
      sortOrder: 1,
      createdAt: now,
      updatedAt: now
    )
    let library = AgentCommandTemplateLibraryV1(templates: [codexFast, codexAggressive])
    let data = try JSONEncoder().encode(library)
    defaults.set(data, forKey: AgentPiDefaults.commandTemplateLibrary)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let fastAfter = service.template(by: "builtin-codex-session-fast")
    let aggressiveAfter = service.template(by: "builtin-codex-session-aggressive")
    #expect(fastAfter?.argsTemplate == ["{{prompt}}"])
    #expect(aggressiveAfter?.argsTemplate == ["--full-auto", "{{prompt}}"])
  }

  @MainActor
  @Test("builtin templates respect configured wrapper commands")
  func builtinTemplatesRespectConfiguredWrapperCommands() {
    let defaults = makeDefaults()
    defaults.set("happy codex", forKey: AgentPiDefaults.codexCommand)
    defaults.set("happy pi", forKey: AgentPiDefaults.piCommand)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let codexTemplate = service.template(by: "builtin-codex-session-fast")
    let piTemplate = service.template(by: "builtin-pi-batch-fast")
    #expect(codexTemplate != nil)
    #expect(piTemplate != nil)
    if let codexTemplate {
      #expect(service.resolvedExecutable(for: codexTemplate) == "happy codex")
    }
    if let piTemplate {
      #expect(service.resolvedExecutable(for: piTemplate) == "happy pi")
    }
  }

  @MainActor
  @Test("custom template executable is not overridden")
  func customTemplateExecutableIsNotOverridden() {
    let defaults = makeDefaults()
    defaults.set("happy codex", forKey: AgentPiDefaults.codexCommand)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let custom = AgentCommandTemplateV1(
      provider: .codex,
      name: "Custom Codex",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "codex-experimental",
      argsTemplate: ["{{prompt}}"],
      enabled: true,
      isBuiltin: false,
      sortOrder: 999
    )
    service.upsertTemplate(custom)

    guard let stored = service.template(by: custom.id) else {
      #expect(Bool(false))
      return
    }
    #expect(service.resolvedExecutable(for: stored) == "codex-experimental")
  }

  @MainActor
  @Test("custom template using base executable inherits configured wrapper")
  func customBaseExecutableInheritsConfiguredWrapper() {
    let defaults = makeDefaults()
    defaults.set("happy codex", forKey: AgentPiDefaults.codexCommand)

    let service = CommandTemplateService(defaults: defaults)
    service.ensureInitialized(
      claudeCommand: "claude",
      codexCommand: "codex",
      piCommand: "pi"
    )

    let custom = AgentCommandTemplateV1(
      provider: .codex,
      name: "Custom Base Codex",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: "codex",
      argsTemplate: ["--no-alt-screen", "{{prompt}}"],
      enabled: true,
      isBuiltin: false,
      sortOrder: 998
    )
    service.upsertTemplate(custom)

    guard let stored = service.template(by: custom.id) else {
      #expect(Bool(false))
      return
    }
    #expect(service.resolvedExecutable(for: stored) == "happy codex")
  }

  private func makeDefaults() -> UserDefaults {
    let suiteName = "agentpi.tests.templates.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
