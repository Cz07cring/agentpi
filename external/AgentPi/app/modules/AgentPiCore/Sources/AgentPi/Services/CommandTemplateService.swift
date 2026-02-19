//
//  CommandTemplateService.swift
//  AgentPi
//
//  Stores, migrates, and resolves command templates for Claude/Codex/AgentPi.
//

import Foundation

@MainActor
public final class CommandTemplateService {
  public static let shared = CommandTemplateService()
  private static let piBatchFastTemplateID = "builtin-pi-batch-fast"
  private static let piRPCServiceTemplateID = "builtin-pi-rpc-service"
  private static let codexSessionFastTemplateID = "builtin-codex-session-fast"
  private static let codexSessionAggressiveTemplateID = "builtin-codex-session-aggressive"
  private static let claudeMobileRelayTemplateID = "builtin-claude-mobile-relay"
  private static let codexMobileRelayTemplateID = "builtin-codex-mobile-relay"
  private static let piMobileRelayTemplateID = "builtin-pi-mobile-relay"

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func ensureInitialized(
    claudeCommand: String,
    codexCommand: String,
    piCommand: String,
    mobileRelayClaudeCommand: String? = nil,
    mobileRelayCodexCommand: String? = nil,
    mobileRelayPiCommand: String? = nil
  ) {
    if !allTemplates().isEmpty {
      migrateCodexNoAltScreenIfNeeded()
      migratePiBatchFastTemplateIfNeeded()
      migratePiRPCBatchTemplateIfNeeded()
      migrateLegacyMobileRelayTemplatesIfNeeded(
        claudeCommand: mobileRelayClaudeCommand,
        codexCommand: mobileRelayCodexCommand,
        piCommand: mobileRelayPiCommand
      )
      ensureDefaultMappings()
      return
    }

    var templates = builtinTemplates()
    let legacy = legacyTemplates(
      claudeCommand: claudeCommand,
      codexCommand: codexCommand,
      piCommand: piCommand
    )
    templates.append(contentsOf: legacy)
    templates = normalizeSortOrder(templates)
    saveTemplates(templates)

    var defaultIds: [String: String] = [:]
    for provider in SessionProviderKind.allCases {
      if let legacyTemplate = templates.first(where: { $0.provider == provider && $0.id.hasPrefix("legacy-") }) {
        defaultIds[provider.stableKey] = legacyTemplate.id
      } else if let firstStart = templates.first(where: { $0.provider == provider && $0.intent == .startSession }) {
        defaultIds[provider.stableKey] = firstStart.id
      }
    }
    saveDefaultTemplateIds(defaultIds)
    saveLastUsedTemplateIds(defaultIds)
    migrateCodexNoAltScreenIfNeeded()
    migratePiBatchFastTemplateIfNeeded()
    migratePiRPCBatchTemplateIfNeeded()
    migrateLegacyMobileRelayTemplatesIfNeeded(
      claudeCommand: mobileRelayClaudeCommand,
      codexCommand: mobileRelayCodexCommand,
      piCommand: mobileRelayPiCommand
    )
    ensureDefaultMappings()
  }

  public func allTemplates() -> [AgentCommandTemplateV1] {
    guard let data = defaults.data(forKey: AgentPiDefaults.commandTemplateLibrary),
      let library = try? decoder.decode(AgentCommandTemplateLibraryV1.self, from: data)
    else {
      return []
    }
    return normalizeSortOrder(library.templates)
  }

  public func templates(
    for provider: SessionProviderKind,
    intent: TemplateIntent? = nil,
    includeDisabled: Bool = false
  ) -> [AgentCommandTemplateV1] {
    allTemplates()
      .filter { template in
        guard template.provider == provider else { return false }
        if !includeDisabled && !template.enabled { return false }
        if let intent, template.intent != intent { return false }
        return true
      }
      .sorted { lhs, rhs in
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
  }

  public func template(by id: String) -> AgentCommandTemplateV1? {
    allTemplates().first(where: { $0.id == id })
  }

  /// Resolves the effective executable command for a template.
  /// Keeps compatibility with legacy CLI command settings (e.g. "happy codex").
  public func resolvedExecutable(for template: AgentCommandTemplateV1) -> String {
    let raw = template.executable.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else {
      return configuredCommand(for: template.provider)
    }

    let configured = configuredCommand(for: template.provider)
    let isLegacyTemplate = template.id.hasPrefix("legacy-")
    let providerBase = baseExecutable(for: template.provider)

    if isLegacyTemplate {
      return configured
    }

    // Treat base executables as aliases of the provider command setting so wrappers
    // like "happy codex"/"happy pi" apply consistently across builtin and custom templates.
    if raw.caseInsensitiveCompare(providerBase) == .orderedSame {
      return configured
    }

    return raw
  }

  public func upsertTemplate(_ template: AgentCommandTemplateV1) {
    var all = allTemplates()
    if let index = all.firstIndex(where: { $0.id == template.id }) {
      var updated = template
      updated.updatedAt = Date()
      all[index] = updated
    } else {
      var inserted = template
      inserted.sortOrder = all.filter { $0.provider == template.provider }.count
      all.append(inserted)
    }
    saveTemplates(normalizeSortOrder(all))
    ensureDefaultMappings()
  }

  public func deleteTemplate(id: String) {
    var all = allTemplates()
    all.removeAll { $0.id == id }
    saveTemplates(normalizeSortOrder(all))

    var defaultsMap = loadDefaultTemplateIds()
    var lastUsedMap = loadLastUsedTemplateIds()
    for provider in SessionProviderKind.allCases {
      if defaultsMap[provider.stableKey] == id {
        defaultsMap[provider.stableKey] = fallbackTemplateId(for: provider, templates: all)
      }
      if lastUsedMap[provider.stableKey] == id {
        lastUsedMap[provider.stableKey] = fallbackTemplateId(for: provider, templates: all)
      }
    }
    saveDefaultTemplateIds(defaultsMap)
    saveLastUsedTemplateIds(lastUsedMap)
  }

  public func moveTemplate(
    provider: SessionProviderKind,
    from source: Int,
    to destination: Int
  ) {
    var providerTemplates = templates(for: provider, includeDisabled: true)
    guard source != destination,
      source >= 0,
      source < providerTemplates.count,
      destination >= 0,
      destination <= providerTemplates.count
    else { return }
    let item = providerTemplates.remove(at: source)
    let target = destination > source ? destination - 1 : destination
    providerTemplates.insert(item, at: target)

    var all = allTemplates().filter { $0.provider != provider }
    for (index, template) in providerTemplates.enumerated() {
      var updated = template
      updated.sortOrder = index
      updated.updatedAt = Date()
      all.append(updated)
    }
    saveTemplates(normalizeSortOrder(all))
  }

  public func setDefaultTemplate(id: String, for provider: SessionProviderKind) {
    var defaultsMap = loadDefaultTemplateIds()
    defaultsMap[provider.stableKey] = id
    saveDefaultTemplateIds(defaultsMap)
  }

  public func defaultTemplate(for provider: SessionProviderKind, intent: TemplateIntent? = nil) -> AgentCommandTemplateV1? {
    let all = allTemplates()
    let defaultsMap = loadDefaultTemplateIds()
    if let configuredId = defaultsMap[provider.stableKey],
      let configured = all.first(where: { $0.id == configuredId && $0.provider == provider && $0.enabled })
    {
      if let intent, configured.intent != intent {
        return all.first(where: { $0.provider == provider && $0.intent == intent && $0.enabled })
      }
      return configured
    }
    if let intent {
      return all.first(where: { $0.provider == provider && $0.intent == intent && $0.enabled })
    }
    return all.first(where: { $0.provider == provider && $0.enabled })
  }

  public func setLastUsedTemplate(id: String, for provider: SessionProviderKind) {
    var map = loadLastUsedTemplateIds()
    map[provider.stableKey] = id
    saveLastUsedTemplateIds(map)
  }

  public func lastUsedTemplate(for provider: SessionProviderKind, intent: TemplateIntent? = nil) -> AgentCommandTemplateV1? {
    let all = allTemplates()
    let map = loadLastUsedTemplateIds()
    if let id = map[provider.stableKey],
      let template = all.first(where: { $0.id == id && $0.provider == provider && $0.enabled })
    {
      if let intent, template.intent != intent {
        return nil
      }
      return template
    }
    return nil
  }

  // MARK: - Private

  private func saveTemplates(_ templates: [AgentCommandTemplateV1]) {
    let valid = templates.filter(\.isStructurallyValid)
    let library = AgentCommandTemplateLibraryV1(templates: valid)
    if let data = try? encoder.encode(library) {
      defaults.set(data, forKey: AgentPiDefaults.commandTemplateLibrary)
    }
  }

  private func migratePiBatchFastTemplateIfNeeded() {
    if defaults.bool(forKey: AgentPiDefaults.migratedPiBatchFastTemplateAdded) {
      return
    }

    var templates = allTemplates()
    defer {
      defaults.set(true, forKey: AgentPiDefaults.migratedPiBatchFastTemplateAdded)
    }

    if templates.contains(where: { $0.id == Self.piBatchFastTemplateID }) {
      return
    }

    guard let batchFastTemplate = builtinTemplates().first(where: { $0.id == Self.piBatchFastTemplateID }) else {
      return
    }

    templates.append(batchFastTemplate)
    saveTemplates(normalizeSortOrder(templates))
  }

  private func migrateCodexNoAltScreenIfNeeded() {
    if defaults.bool(forKey: AgentPiDefaults.migratedCodexNoAltScreenRemoved) {
      return
    }

    var templates = allTemplates()
    defer {
      defaults.set(true, forKey: AgentPiDefaults.migratedCodexNoAltScreenRemoved)
    }

    var changed = false
    for index in templates.indices {
      let templateID = templates[index].id
      guard templateID == Self.codexSessionFastTemplateID || templateID == Self.codexSessionAggressiveTemplateID else {
        continue
      }

      let previousArgs = templates[index].argsTemplate
      let nextArgs = previousArgs.filter { $0.caseInsensitiveCompare("--no-alt-screen") != .orderedSame }
      guard nextArgs != previousArgs else { continue }
      templates[index].argsTemplate = nextArgs
      templates[index].updatedAt = Date()
      changed = true
    }

    if changed {
      saveTemplates(normalizeSortOrder(templates))
    }
  }

  private func migratePiRPCBatchTemplateIfNeeded() {
    if defaults.bool(forKey: AgentPiDefaults.migratedPiRPCBatchTemplateDisabled) {
      return
    }

    var templates = allTemplates()
    defer {
      defaults.set(true, forKey: AgentPiDefaults.migratedPiRPCBatchTemplateDisabled)
    }

    guard let index = templates.firstIndex(where: { $0.id == Self.piRPCServiceTemplateID }) else {
      return
    }

    if templates[index].enabled {
      templates[index].enabled = false
      templates[index].updatedAt = Date()
      saveTemplates(normalizeSortOrder(templates))
    }
  }

  private func migrateLegacyMobileRelayTemplatesIfNeeded(
    claudeCommand: String?,
    codexCommand: String?,
    piCommand: String?
  ) {
    if defaults.bool(forKey: AgentPiDefaults.migratedMobileRelayTemplatesAdded) {
      return
    }

    var templates = allTemplates()
    let builtinById = Dictionary(uniqueKeysWithValues: builtinTemplates().map { ($0.id, $0) })
    defer {
      defaults.set(true, forKey: AgentPiDefaults.migratedMobileRelayTemplatesAdded)
    }

    func ensureBuiltinTemplate(_ id: String) {
      guard templates.contains(where: { $0.id == id }) == false,
        var builtin = builtinById[id]
      else { return }
      builtin.sortOrder = templates.filter { $0.provider == builtin.provider }.count
      templates.append(builtin)
    }

    ensureBuiltinTemplate(Self.claudeMobileRelayTemplateID)
    ensureBuiltinTemplate(Self.codexMobileRelayTemplateID)
    ensureBuiltinTemplate(Self.piMobileRelayTemplateID)

    func migrateTemplate(
      provider: SessionProviderKind,
      id: String,
      fallbackName: String,
      command: String?
    ) {
      guard let command else { return }
      let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalized.isEmpty else { return }

      let existing = templates.contains {
        $0.provider == provider
          && $0.intent == .mobileRelay
          && ($0.id == id || $0.executable.caseInsensitiveCompare(normalized) == .orderedSame)
      }
      guard !existing else { return }

      let now = Date()
      let migrated = AgentCommandTemplateV1(
        id: id,
        provider: provider,
        name: fallbackName,
        intent: .mobileRelay,
        executionKind: .externalTerminal,
        executable: normalized,
        argsTemplate: ["--project", "{{project_path}}", "--handoff", "{{handoff_jsonl}}"],
        enabled: true,
        isBuiltin: false,
        sortOrder: templates.filter { $0.provider == provider }.count,
        createdAt: now,
        updatedAt: now
      )
      templates.append(migrated)
    }

    migrateTemplate(
      provider: .claude,
      id: "migrated-claude-mobile-relay",
      fallbackName: "Claude Mobile Relay (Migrated)",
      command: claudeCommand
    )
    migrateTemplate(
      provider: .codex,
      id: "migrated-codex-mobile-relay",
      fallbackName: "Codex Mobile Relay (Migrated)",
      command: codexCommand
    )
    migrateTemplate(
      provider: .pi,
      id: "migrated-pi-mobile-relay",
      fallbackName: "AgentPi Mobile Relay (Migrated)",
      command: piCommand
    )

    saveTemplates(normalizeSortOrder(templates))
  }

  private func normalizeSortOrder(_ templates: [AgentCommandTemplateV1]) -> [AgentCommandTemplateV1] {
    var result: [AgentCommandTemplateV1] = []
    for provider in SessionProviderKind.allCases {
      let providerTemplates = templates
        .filter { $0.provider == provider }
        .sorted { lhs, rhs in
          if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
          return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
      for (index, template) in providerTemplates.enumerated() {
        var updated = template
        updated.sortOrder = index
        result.append(updated)
      }
    }
    return result
  }

  private func ensureDefaultMappings() {
    let templates = allTemplates()
    guard !templates.isEmpty else { return }
    var defaultsMap = loadDefaultTemplateIds()
    var lastUsedMap = loadLastUsedTemplateIds()
    var changed = false
    for provider in SessionProviderKind.allCases {
      if defaultsMap[provider.stableKey] == nil
        || !templates.contains(where: { $0.id == defaultsMap[provider.stableKey] && $0.provider == provider && $0.enabled })
      {
        defaultsMap[provider.stableKey] = fallbackTemplateId(for: provider, templates: templates)
        changed = true
      }
      if lastUsedMap[provider.stableKey] == nil
        || !templates.contains(where: { $0.id == lastUsedMap[provider.stableKey] && $0.provider == provider && $0.enabled })
      {
        lastUsedMap[provider.stableKey] = defaultsMap[provider.stableKey]
        changed = true
      }
    }
    if changed {
      saveDefaultTemplateIds(defaultsMap)
      saveLastUsedTemplateIds(lastUsedMap)
    }
  }

  private func fallbackTemplateId(for provider: SessionProviderKind, templates: [AgentCommandTemplateV1]) -> String? {
    templates.first(where: { $0.provider == provider && $0.enabled && $0.intent == .startSession })?.id
      ?? templates.first(where: { $0.provider == provider && $0.enabled })?.id
  }

  private func baseExecutable(for provider: SessionProviderKind) -> String {
    switch provider {
    case .claude: return "claude"
    case .codex: return "codex"
    case .pi: return "pi"
    }
  }

  private func configuredCommand(for provider: SessionProviderKind) -> String {
    let configured: String?
    switch provider {
    case .claude:
      configured = defaults.string(forKey: AgentPiDefaults.claudeCommand)
    case .codex:
      configured = defaults.string(forKey: AgentPiDefaults.codexCommand)
    case .pi:
      configured = defaults.string(forKey: AgentPiDefaults.piCommand)
    }
    let normalized = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let normalized, !normalized.isEmpty {
      return normalized
    }
    return baseExecutable(for: provider)
  }

  private func loadDefaultTemplateIds() -> [String: String] {
    guard let data = defaults.data(forKey: AgentPiDefaults.defaultTemplateIds),
      let map = try? decoder.decode([String: String].self, from: data)
    else { return [:] }
    return map
  }

  private func saveDefaultTemplateIds(_ ids: [String: String]) {
    if let data = try? encoder.encode(ids) {
      defaults.set(data, forKey: AgentPiDefaults.defaultTemplateIds)
    }
  }

  private func loadLastUsedTemplateIds() -> [String: String] {
    guard let data = defaults.data(forKey: AgentPiDefaults.lastUsedTemplateIds),
      let map = try? decoder.decode([String: String].self, from: data)
    else { return [:] }
    return map
  }

  private func saveLastUsedTemplateIds(_ ids: [String: String]) {
    if let data = try? encoder.encode(ids) {
      defaults.set(data, forKey: AgentPiDefaults.lastUsedTemplateIds)
    }
  }

  private func legacyTemplates(
    claudeCommand: String,
    codexCommand: String,
    piCommand: String
  ) -> [AgentCommandTemplateV1] {
    let now = Date()
    return [
      AgentCommandTemplateV1(
        id: "legacy-claude-start",
        provider: .claude,
        name: "Legacy Claude",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: claudeCommand,
        argsTemplate: ["{{prompt}}"],
        enabled: true,
        isBuiltin: false,
        sortOrder: 1000,
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "legacy-codex-start",
        provider: .codex,
        name: "Legacy Codex",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: codexCommand,
        argsTemplate: ["{{prompt}}"],
        enabled: true,
        isBuiltin: false,
        sortOrder: 1000,
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "legacy-pi-start",
        provider: .pi,
        name: "Legacy AgentPi",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: piCommand,
        argsTemplate: ["{{prompt}}"],
        enabled: true,
        isBuiltin: false,
        sortOrder: 1000,
        createdAt: now,
        updatedAt: now
      )
    ]
  }

  private func builtinTemplates() -> [AgentCommandTemplateV1] {
    let now = Date()
    var order = 0
    func nextOrder() -> Int {
      defer { order += 1 }
      return order
    }

    return [
      AgentCommandTemplateV1(
        id: "builtin-claude-session-fast",
        provider: .claude,
        name: "Session Fast",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: "claude",
        argsTemplate: ["--dangerously-skip-permissions", "{{prompt}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-claude-batch-fast",
        provider: .claude,
        name: "Batch Fast",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "claude",
        argsTemplate: ["-p", "{{prompt}}", "--dangerously-skip-permissions"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-claude-batch-stream",
        provider: .claude,
        name: "Batch Stream Verbose",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "claude",
        argsTemplate: ["-p", "{{prompt}}", "--dangerously-skip-permissions", "--output-format", "stream-json", "--verbose"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: Self.claudeMobileRelayTemplateID,
        provider: .claude,
        name: "Mobile Relay",
        intent: .mobileRelay,
        executionKind: .externalTerminal,
        executable: "happy",
        argsTemplate: ["--project", "{{project_path}}", "--handoff", "{{handoff_jsonl}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-codex-session-fast",
        provider: .codex,
        name: "Session Fast",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: "codex",
        argsTemplate: ["{{prompt}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-codex-session-aggressive",
        provider: .codex,
        name: "Session Aggressive",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: "codex",
        argsTemplate: ["--full-auto", "{{prompt}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-codex-batch-jsonl",
        provider: .codex,
        name: "Batch JSONL",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "codex",
        argsTemplate: ["exec", "{{prompt}}", "--json", "--skip-git-repo-check"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: Self.codexMobileRelayTemplateID,
        provider: .codex,
        name: "Mobile Relay",
        intent: .mobileRelay,
        executionKind: .externalTerminal,
        executable: "happy codex",
        argsTemplate: ["--project", "{{project_path}}", "--handoff", "{{handoff_jsonl}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-pi-session-stable",
        provider: .pi,
        name: "Session Stable",
        intent: .startSession,
        executionKind: .interactiveSession,
        executable: "pi",
        argsTemplate: ["--no-extensions", "--no-skills", "--no-themes", "{{prompt}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: Self.piMobileRelayTemplateID,
        provider: .pi,
        name: "Mobile Relay",
        intent: .mobileRelay,
        executionKind: .externalTerminal,
        executable: "happy pi",
        argsTemplate: ["--project", "{{project_path}}", "--handoff", "{{handoff_jsonl}}"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-pi-batch-fast",
        provider: .pi,
        name: "Batch Fast",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "pi",
        argsTemplate: ["-p", "{{prompt}}", "--no-extensions", "--no-skills", "--no-themes"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-pi-batch-json",
        provider: .pi,
        name: "Batch JSON",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "pi",
        argsTemplate: ["-p", "{{prompt}}", "--mode", "json"],
        enabled: true,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      ),
      AgentCommandTemplateV1(
        id: "builtin-pi-rpc-service",
        provider: .pi,
        name: "RPC Service (Advanced)",
        intent: .batchRun,
        executionKind: .batchRun,
        executable: "pi",
        argsTemplate: ["--mode", "rpc", "--no-extensions", "--no-skills", "--no-themes"],
        enabled: false,
        isBuiltin: true,
        sortOrder: nextOrder(),
        createdAt: now,
        updatedAt: now
      )
    ]
  }
}
