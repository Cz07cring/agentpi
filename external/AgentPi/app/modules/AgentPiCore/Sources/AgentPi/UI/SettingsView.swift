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

  @AppStorage(AgentPiDefaults.claudeCommandLockedByDeveloper)
  private var claudeCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.codexCommandLockedByDeveloper)
  private var codexCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.piCommandLockedByDeveloper)
  private var piCommandLocked: Bool = false

  @AppStorage(AgentPiDefaults.selectedLanguage)
  private var selectedLanguage: String = AppLanguage.system.rawValue

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
    }
    .task {
      await ensureSupportedThemeSelection()
    }
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
