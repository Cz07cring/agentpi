//
//  SettingsView.swift
//  AgentPi
//
//  Settings panel for app configuration.
//

import SwiftUI

private enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case english = "en"
  case chineseSimplified = "zh-Hans"
  case korean = "ko"
  case japanese = "ja"
  case vietnamese = "vi"

  var id: String { rawValue }

  var localizedName: String {
    switch self {
    case .system: return L10n.t("settings.language.system", "Follow System")
    case .english: return L10n.t("settings.language.english", "English")
    case .chineseSimplified: return L10n.t("settings.language.chinese_simplified", "简体中文")
    case .korean: return L10n.t("settings.language.korean", "한국어")
    case .japanese: return L10n.t("settings.language.japanese", "日本語")
    case .vietnamese: return L10n.t("settings.language.vietnamese", "Tiếng Việt")
    }
  }
}

public struct SettingsView: View {
  @AppStorage(AgentPiDefaults.smartModeEnabled)
  private var smartModeEnabled: Bool = false

  @AppStorage(AgentPiDefaults.uxGuidedHintsEnabled)
  private var uxGuidedHintsEnabled: Bool = true

  @AppStorage(AgentPiDefaults.uxExpertQuickMode)
  private var uxExpertQuickMode: Bool = false

  @AppStorage(AgentPiDefaults.notificationSoundsEnabled)
  private var notificationSoundsEnabled: Bool = true

  @AppStorage(AgentPiDefaults.proxyEnabled)
  private var proxyEnabled: Bool = false

  @AppStorage(AgentPiDefaults.proxyHTTP)
  private var proxyHTTP: String = AgentPiDefaults.defaultProxyHTTP

  @AppStorage(AgentPiDefaults.proxyHTTPS)
  private var proxyHTTPS: String = AgentPiDefaults.defaultProxyHTTPS

  @AppStorage(AgentPiDefaults.proxyALL)
  private var proxyALL: String = AgentPiDefaults.defaultProxyALL

  @AppStorage(AgentPiDefaults.proxyNO)
  private var proxyNO: String = AgentPiDefaults.defaultProxyNO

  @AppStorage(AgentPiDefaults.claudeCommand)
  private var claudeCommand: String = "claude"

  @AppStorage(AgentPiDefaults.codexCommand)
  private var codexCommand: String = "codex"

  @AppStorage(AgentPiDefaults.piCommand)
  private var piCommand: String = "pi"

  @AppStorage(AgentPiDefaults.mobileRelayAutoSwitchPanel)
  private var mobileRelayAutoSwitchPanel: Bool = true

  @AppStorage(AgentPiDefaults.claudeCommandLockedByDeveloper)
  private var claudeCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.codexCommandLockedByDeveloper)
  private var codexCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.piCommandLockedByDeveloper)
  private var piCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.selectedLanguage)
  private var selectedLanguage: String = AppLanguage.system.rawValue

  @State private var templateProviderFilter: SessionProviderKind = .claude
  @State private var templateRefreshTick: Int = 0
  @State private var editingTemplate: AgentCommandTemplateV1?
  @State private var templateEditorDraft: TemplateEditorDraft = .empty
  @State private var isTemplateEditorPresented: Bool = false

  @Environment(ThemeManager.self) private var themeManager
  @AppStorage(AgentPiDefaults.selectedTheme) private var selectedThemeId: String = "claude"
  private let defaultThemeId = "claude"
  private let sentryThemeFileId = "sentry.yaml"

  public init() {}

  public var body: some View {
    Form {
      Section(L10n.t("settings.cli_status.section", "CLI Status")) {
        DisclosureGroup {
          HStack {
            Text(L10n.t("settings.command.label", "Command:"))
              .foregroundColor(.secondary)
            TextField("claude", text: $claudeCommand)
              .textFieldStyle(.roundedBorder)
              .disabled(claudeCommandLocked)
            if claudeCommandLocked {
              Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .padding(.vertical, 4)

          HStack {
            Link(
              L10n.t("settings.install_guide", "Install Guide"),
              destination: CLIDetectionService.providerInstallURL(for: .claude)
            )
            .font(.caption)
            Spacer()
          }
        } label: {
          HStack {
            Text(L10n.t("settings.provider.claude", "Claude"))
              .foregroundColor(Color.brandPrimary(for: .claude))
            Spacer()
            if CLIDetectionService.isClaudeInstalled() {
              Label(L10n.t("settings.installed", "Installed"), systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            } else {
              Label(L10n.t("settings.not_installed", "Not Installed"), systemImage: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
        }

        DisclosureGroup {
          HStack {
            Text(L10n.t("settings.command.label", "Command:"))
              .foregroundColor(.secondary)
            TextField("codex", text: $codexCommand)
              .textFieldStyle(.roundedBorder)
              .disabled(codexCommandLocked)
            if codexCommandLocked {
              Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .padding(.vertical, 4)

          HStack {
            Link(
              L10n.t("settings.install_guide", "Install Guide"),
              destination: CLIDetectionService.providerInstallURL(for: .codex)
            )
            .font(.caption)
            Spacer()
          }
        } label: {
          HStack {
            Text(L10n.t("settings.provider.codex", "Codex"))
              .foregroundColor(Color.brandPrimary(for: .codex))
            Spacer()
            if CLIDetectionService.isCodexInstalled() {
              Label(L10n.t("settings.installed", "Installed"), systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            } else {
              Label(L10n.t("settings.not_installed", "Not Installed"), systemImage: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
        }

        DisclosureGroup {
          HStack {
            Text(L10n.t("settings.command.label", "Command:"))
              .foregroundColor(.secondary)
            TextField("pi", text: $piCommand)
              .textFieldStyle(.roundedBorder)
              .disabled(piCommandLocked)
            if piCommandLocked {
              Image(systemName: "lock.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
          .padding(.vertical, 4)

          HStack {
            Link(
              L10n.t("settings.install_guide", "Install Guide"),
              destination: CLIDetectionService.providerInstallURL(for: .pi)
            )
            .font(.caption)
            Spacer()
          }
        } label: {
          HStack {
            Text(L10n.t("settings.provider.agentpi", "AgentPi"))
              .foregroundColor(Color.brandPrimary(for: .pi))
            Spacer()
            if CLIDetectionService.isPiInstalled() {
              Label(L10n.t("settings.installed", "Installed"), systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            } else {
              Label(L10n.t("settings.not_installed", "Not Installed"), systemImage: "xmark.circle.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
        }
      }

      Section(L10n.t("settings.mobile_relay.section", "Mobile Relay")) {
        Text(L10n.t(
          "settings.mobile_relay.note",
          "Mobile handoff runs from session cards. Configure relay behavior and preferred templates here."
        ))
        .font(.caption)
        .foregroundColor(.secondary)

        Toggle(
          L10n.t("settings.mobile_relay.auto_switch", "Auto switch to Mobile Relay panel after launch"),
          isOn: $mobileRelayAutoSwitchPanel
        )

        mobileRelayTemplatePreferenceRow(for: .claude)
        mobileRelayTemplatePreferenceRow(for: .codex)
        mobileRelayTemplatePreferenceRow(for: .pi)
      }

      Section {
        Toggle(isOn: $notificationSoundsEnabled) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t("settings.notifications.sound.title", "Notification sounds"))
            Text(L10n.t("settings.notifications.sound.subtitle", "Play a sound when tools require approval"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      } header: {
        Text(L10n.t("settings.notifications.section", "Notifications"))
      }

      Section(L10n.t("settings.features.section", "Features")) {
        Toggle(isOn: $smartModeEnabled) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t("settings.features.smart_mode.title", "Smart mode"))
            Text(L10n.t("settings.features.smart_mode.subtitle", "Use AI to plan and orchestrate multi-session launches"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Section(L10n.t("settings.network.section", "Network")) {
        Toggle(isOn: $proxyEnabled) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t("settings.network.proxy.enable", "Enable proxy for CLI sessions"))
            Text(L10n.t("settings.network.proxy.enable.subtitle", "Inject HTTP/HTTPS/ALL_PROXY when launching Claude/Codex/AgentPi"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        TextField(
          L10n.t("settings.network.proxy.http", "HTTP Proxy (http://127.0.0.1:7890)"),
          text: $proxyHTTP
        )
        .textFieldStyle(.roundedBorder)
        .disabled(!proxyEnabled)

        TextField(
          L10n.t("settings.network.proxy.https", "HTTPS Proxy (http://127.0.0.1:7890)"),
          text: $proxyHTTPS
        )
        .textFieldStyle(.roundedBorder)
        .disabled(!proxyEnabled)

        TextField(
          L10n.t("settings.network.proxy.all", "ALL_PROXY (socks5://127.0.0.1:7890)"),
          text: $proxyALL
        )
        .textFieldStyle(.roundedBorder)
        .disabled(!proxyEnabled)

        TextField(
          L10n.t("settings.network.proxy.no", "NO_PROXY (localhost,127.0.0.1)"),
          text: $proxyNO
        )
        .textFieldStyle(.roundedBorder)
        .disabled(!proxyEnabled)

        Text(L10n.t("settings.network.proxy.note", "Restart active sessions after changing proxy settings."))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Section(L10n.t("settings.templates.section", "Command Templates")) {
        Picker(
          L10n.t("settings.templates.provider_filter", "Provider"),
          selection: $templateProviderFilter
        ) {
          Text(L10n.t("settings.provider.claude", "Claude")).tag(SessionProviderKind.claude)
          Text(L10n.t("settings.provider.codex", "Codex")).tag(SessionProviderKind.codex)
          Text(L10n.t("settings.provider.agentpi", "AgentPi")).tag(SessionProviderKind.pi)
        }

        if filteredTemplates.isEmpty {
          Text(L10n.t("settings.templates.empty", "No templates for this provider. Create one to continue."))
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          ForEach(Array(filteredTemplates.enumerated()), id: \.element.id) { index, template in
            templateRow(template, index: index)
          }
        }

        HStack {
          Button(L10n.t("settings.templates.add", "Add Template")) {
            editingTemplate = nil
            templateEditorDraft = .newDraft(for: templateProviderFilter)
            isTemplateEditorPresented = true
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)

          Spacer()
        }
      }

      Section(L10n.t("settings.ux.section", "UX")) {
        Toggle(isOn: $uxGuidedHintsEnabled) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t("settings.ux.guided_hints", "Guided hints"))
            Text(L10n.t("settings.ux.guided_hints.subtitle", "Show step-by-step hints in launcher"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Toggle(isOn: $uxExpertQuickMode) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t("settings.ux.expert_quick_mode", "Expert quick mode"))
            Text(L10n.t("settings.ux.expert_quick_mode.subtitle", "Use compact launcher cues with less guidance"))
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      Section(L10n.t("settings.language.section", "Language")) {
        Picker(L10n.t("settings.language.label", "App Language"), selection: $selectedLanguage) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.localizedName).tag(language.rawValue)
          }
        }

        Text(L10n.t("settings.language.note", "UI language changes apply immediately in desktop app windows."))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Section {
        Picker(L10n.t("settings.theme.section", "Theme"), selection: themeSelectionBinding) {
          Text(L10n.t("settings.theme.default", "Default")).tag(defaultThemeId)
          Text(L10n.t("settings.theme.sentry", "Sentry")).tag(sentryThemeFileId)
        }

        HStack(spacing: 8) {
          Button(action: {
            Task { await themeManager.discoverThemes() }
          }) {
            Image(systemName: "arrow.clockwise")
          }
          .help(L10n.t("settings.theme.refresh_help", "Refresh theme list"))
        }
      } header: {
        Text(L10n.t("settings.theme.section", "Theme"))
      } footer: {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
          Text(L10n.f("settings.version.format", "AgentPi v%@", appVersion))
            .font(.caption)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 300, height: 500)
    .onAppear {
      applyProxyDefaultsIfEmpty()
      templateRefreshTick += 1
    }
    .task {
      await ensureSupportedThemeSelection()
    }
    .sheet(isPresented: $isTemplateEditorPresented) {
      TemplateEditorSheet(
        draft: $templateEditorDraft,
        onCancel: { isTemplateEditorPresented = false },
        onSave: {
          saveTemplateDraft()
          isTemplateEditorPresented = false
        }
      )
    }
  }

  private var commandTemplateService: CommandTemplateService {
    .shared
  }

  private var filteredTemplates: [AgentCommandTemplateV1] {
    _ = templateRefreshTick
    return commandTemplateService.templates(for: templateProviderFilter, includeDisabled: true)
  }

  @ViewBuilder
  private func templateRow(_ template: AgentCommandTemplateV1, index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(template.name)
          .font(.system(size: 12, weight: .semibold))
        Text(template.intent.rawValue)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(Color.primary.opacity(0.08))
          )
        if defaultTemplateId(for: template.provider) == template.id {
          Text(L10n.t("settings.templates.default_badge", "Default"))
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.brandPrimary)
        }
        Spacer(minLength: 0)
      }

      Text(template.executable + (template.argsTemplate.isEmpty ? "" : " " + template.argsTemplate.joined(separator: " ")))
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
        .lineLimit(2)
        .textSelection(.enabled)

      HStack(spacing: 8) {
        Button(L10n.t("settings.templates.edit", "Edit")) {
          editingTemplate = template
          templateEditorDraft = TemplateEditorDraft(template: template)
          isTemplateEditorPresented = true
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)

        Button(L10n.t("settings.templates.copy", "Copy")) {
          var copied = template
          copied.id = UUID().uuidString
          copied.name = "\(template.name) Copy"
          copied.isBuiltin = false
          copied.createdAt = Date()
          copied.updatedAt = Date()
          commandTemplateService.upsertTemplate(copied)
          templateRefreshTick += 1
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)

        Button(template.enabled
          ? L10n.t("settings.templates.disable", "Disable")
          : L10n.t("settings.templates.enable", "Enable")
        ) {
          var updated = template
          updated.enabled.toggle()
          updated.updatedAt = Date()
          commandTemplateService.upsertTemplate(updated)
          templateRefreshTick += 1
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)

        Menu(L10n.t("settings.templates.more", "More")) {
          Button(L10n.t("settings.templates.set_default", "Set Default")) {
            commandTemplateService.setDefaultTemplate(id: template.id, for: template.provider)
            templateRefreshTick += 1
          }
          Button(L10n.t("settings.templates.move_up", "Move Up")) {
            guard index > 0 else { return }
            commandTemplateService.moveTemplate(
              provider: template.provider,
              from: index,
              to: index - 1
            )
            templateRefreshTick += 1
          }
          Button(L10n.t("settings.templates.move_down", "Move Down")) {
            guard index < filteredTemplates.count - 1 else { return }
            commandTemplateService.moveTemplate(
              provider: template.provider,
              from: index,
              to: index + 2
            )
            templateRefreshTick += 1
          }
          Divider()
          Button(L10n.t("settings.templates.delete", "Delete"), role: .destructive) {
            commandTemplateService.deleteTemplate(id: template.id)
            templateRefreshTick += 1
          }
        }
        .controlSize(.mini)
      }
    }
    .padding(.vertical, 4)
  }

  private func defaultTemplateId(for provider: SessionProviderKind) -> String? {
    commandTemplateService.defaultTemplate(for: provider)?.id
  }

  private func saveTemplateDraft() {
    let normalizedName = templateEditorDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedExecutable = templateEditorDraft.executable.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty, !normalizedExecutable.isEmpty else { return }

    let args = CLICommandConfiguration.tokenizeCommand(templateEditorDraft.argsText)
    let template = AgentCommandTemplateV1(
      id: editingTemplate?.id ?? UUID().uuidString,
      provider: templateEditorDraft.provider,
      name: normalizedName,
      intent: templateEditorDraft.intent,
      executionKind: templateEditorDraft.executionKind,
      executable: normalizedExecutable,
      argsTemplate: args,
      enabled: templateEditorDraft.enabled,
      isBuiltin: editingTemplate?.isBuiltin ?? false,
      sortOrder: editingTemplate?.sortOrder ?? 0,
      createdAt: editingTemplate?.createdAt ?? Date(),
      updatedAt: Date()
    )
    commandTemplateService.upsertTemplate(template)
    templateRefreshTick += 1
  }

  private func applyProxyDefaultsIfEmpty() {
    let httpEmpty = proxyHTTP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let httpsEmpty = proxyHTTPS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let allEmpty = proxyALL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let noEmpty = proxyNO.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    guard httpEmpty && httpsEmpty && allEmpty && noEmpty else { return }
    proxyHTTP = AgentPiDefaults.defaultProxyHTTP
    proxyHTTPS = AgentPiDefaults.defaultProxyHTTPS
    proxyALL = AgentPiDefaults.defaultProxyALL
    proxyNO = AgentPiDefaults.defaultProxyNO
  }

  @ViewBuilder
  private func mobileRelayTemplatePreferenceRow(for provider: SessionProviderKind) -> some View {
    let templates = commandTemplateService.templates(for: provider, intent: .mobileRelay, includeDisabled: false)
    let selected = commandTemplateService.lastUsedTemplate(for: provider, intent: .mobileRelay)
      ?? commandTemplateService.defaultTemplate(for: provider, intent: .mobileRelay)

    VStack(alignment: .leading, spacing: 6) {
      Text(providerTitle(provider))
        .font(.system(size: 12, weight: .semibold))

      if templates.isEmpty {
        Text(L10n.t("settings.mobile_relay.no_template", "No mobile relay template configured for this provider."))
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        Menu(selected?.name ?? L10n.t("settings.mobile_relay.select_template", "Select template")) {
          ForEach(templates, id: \.id) { template in
            Button(template.name) {
              commandTemplateService.setLastUsedTemplate(id: template.id, for: provider)
              templateRefreshTick += 1
            }
          }
        }
      }
    }
    .padding(.vertical, 2)
  }

  private func providerTitle(_ provider: SessionProviderKind) -> String {
    switch provider {
    case .claude:
      return L10n.t("settings.provider.claude", "Claude")
    case .codex:
      return L10n.t("settings.provider.codex", "Codex")
    case .pi:
      return L10n.t("settings.provider.agentpi", "AgentPi")
    }
  }

  private var themeSelectionBinding: Binding<String> {
    Binding(
      get: {
        isSentryThemeId(selectedThemeId) ? sentryThemeFileId : defaultThemeId
      },
      set: { newValue in
        Task {
          await applyThemeSelection(newValue)
        }
      }
    )
  }

  private func ensureSupportedThemeSelection() async {
    if isSentryThemeId(selectedThemeId) {
      await applyThemeSelection(sentryThemeFileId)
      return
    }

    if selectedThemeId != defaultThemeId {
      selectedThemeId = defaultThemeId
      themeManager.loadBuiltInTheme(.claude)
    }
  }

  private func applyThemeSelection(_ selection: String) async {
    if selection == defaultThemeId {
      selectedThemeId = defaultThemeId
      themeManager.loadBuiltInTheme(.claude)
      return
    }

    await themeManager.discoverThemes()

    if let sentryTheme = themeManager.availableYAMLThemes.first(where: isSentryTheme),
       let fileURL = sentryTheme.fileURL {
      try? await themeManager.loadTheme(fileURL: fileURL)
      selectedThemeId = sentryTheme.id
      return
    }

    let sentryURL = ThemeManager.themesDirectory().appendingPathComponent(sentryThemeFileId)
    if FileManager.default.fileExists(atPath: sentryURL.path) {
      try? await themeManager.loadTheme(fileURL: sentryURL)
      selectedThemeId = sentryThemeFileId
      return
    }

    selectedThemeId = defaultThemeId
    themeManager.loadBuiltInTheme(.claude)
  }

  private func isSentryTheme(_ metadata: ThemeManager.ThemeMetadata) -> Bool {
    isSentryThemeId(metadata.id) || metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "sentry"
  }

  private func isSentryThemeId(_ value: String) -> Bool {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "sentry" || normalized == "sentry.yaml" || normalized == "sentry.yml"
  }
}

private struct TemplateEditorDraft {
  var provider: SessionProviderKind
  var name: String
  var intent: TemplateIntent
  var executionKind: TemplateExecutionKind
  var executable: String
  var argsText: String
  var enabled: Bool

  init(
    provider: SessionProviderKind,
    name: String,
    intent: TemplateIntent,
    executionKind: TemplateExecutionKind,
    executable: String,
    argsText: String,
    enabled: Bool
  ) {
    self.provider = provider
    self.name = name
    self.intent = intent
    self.executionKind = executionKind
    self.executable = executable
    self.argsText = argsText
    self.enabled = enabled
  }

  static let empty = TemplateEditorDraft(
    provider: .claude,
    name: "",
    intent: .startSession,
    executionKind: .interactiveSession,
    executable: "",
    argsText: "",
    enabled: true
  )

  static func newDraft(for provider: SessionProviderKind) -> TemplateEditorDraft {
    TemplateEditorDraft(
      provider: provider,
      name: "",
      intent: .startSession,
      executionKind: .interactiveSession,
      executable: provider == .pi ? "pi" : provider == .codex ? "codex" : "claude",
      argsText: "{{prompt}}",
      enabled: true
    )
  }

  init(template: AgentCommandTemplateV1) {
    provider = template.provider
    name = template.name
    intent = template.intent
    executionKind = template.executionKind
    executable = template.executable
    argsText = template.argsTemplate.joined(separator: " ")
    enabled = template.enabled
  }
}

private struct TemplateEditorSheet: View {
  @Binding var draft: TemplateEditorDraft
  let onCancel: () -> Void
  let onSave: () -> Void

  private var canSave: Bool {
    !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !draft.executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(L10n.t("settings.templates.editor.title", "Edit Template"))
        .font(.headline)

      Picker(L10n.t("settings.templates.provider_filter", "Provider"), selection: $draft.provider) {
        Text(L10n.t("settings.provider.claude", "Claude")).tag(SessionProviderKind.claude)
        Text(L10n.t("settings.provider.codex", "Codex")).tag(SessionProviderKind.codex)
        Text(L10n.t("settings.provider.agentpi", "AgentPi")).tag(SessionProviderKind.pi)
      }

      TextField(L10n.t("settings.templates.field.name", "Name"), text: $draft.name)
        .textFieldStyle(.roundedBorder)

      Picker(L10n.t("settings.templates.field.intent", "Intent"), selection: $draft.intent) {
        Text("start_session").tag(TemplateIntent.startSession)
        Text("resume_session").tag(TemplateIntent.resumeSession)
        Text("batch_run").tag(TemplateIntent.batchRun)
        Text("mobile_relay").tag(TemplateIntent.mobileRelay)
      }

      Picker(L10n.t("settings.templates.field.execution_kind", "Execution Kind"), selection: $draft.executionKind) {
        Text("interactive_session").tag(TemplateExecutionKind.interactiveSession)
        Text("batch_run").tag(TemplateExecutionKind.batchRun)
        Text("external_terminal").tag(TemplateExecutionKind.externalTerminal)
      }

      TextField(L10n.t("settings.templates.field.executable", "Executable"), text: $draft.executable)
        .textFieldStyle(.roundedBorder)

      TextField(L10n.t("settings.templates.field.args", "Arguments (tokenized)"), text: $draft.argsText)
        .textFieldStyle(.roundedBorder)

      Toggle(L10n.t("settings.templates.field.enabled", "Enabled"), isOn: $draft.enabled)

      if !canSave {
        Text(L10n.t("settings.templates.validation.required", "Name and executable are required."))
          .font(.caption)
          .foregroundColor(.orange)
      }

      HStack {
        Spacer()
        Button(L10n.t("settings.cancel", "Cancel"), action: onCancel)
        Button(L10n.t("settings.save", "Save"), action: onSave)
          .buttonStyle(.borderedProminent)
          .disabled(!canSave)
      }
    }
    .padding(16)
    .frame(minWidth: 520)
  }
}
