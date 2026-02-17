//
//  CLINotInstalledView.swift
//  AgentPi
//
//  Shows "CLI Not Installed" state for a specific provider.
//

import SwiftUI

/// Empty state view shown when a CLI provider is not installed
public struct CLINotInstalledView: View {
  let provider: SessionProviderKind
  @Environment(\.openSettings) private var openSettings

  public init(provider: SessionProviderKind) {
    self.provider = provider
  }

  public var body: some View {
    VStack {
      VStack(spacing: 20) {
        ZStack {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color.brandPrimary(for: provider).opacity(0.2),
                  Color.brandPrimary(for: provider).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 72, height: 72)

          Image(systemName: "terminal")
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .foregroundColor(Color.brandPrimary(for: provider))
        }

        VStack(spacing: 8) {
          Text(
            L10n.f(
              "cli_not_installed.title",
              "%@ CLI Not Installed",
              provider.rawValue
            )
          )
            .font(.system(.headline, design: .rounded))

          Text(installationMessage)
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }

        HStack(spacing: 8) {
          Button {
            openSettings()
          } label: {
            Label(L10n.t("launch.action.open_settings", "Open Settings"), systemImage: "gearshape")
              .font(.subheadline)
          }
          .buttonStyle(.bordered)

          Link(destination: installationURL) {
            Label(L10n.t("cli_not_installed.installation_guide", "Installation Guide"), systemImage: "arrow.up.right.circle.fill")
              .font(.subheadline)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.brandPrimary(for: provider))
        }
      }
      .padding(24)
      .agentPiCard(isHighlighted: true)
      .frame(maxWidth: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  private var installationMessage: String {
    switch provider {
    case .claude:
      return L10n.t(
        "cli_not_installed.message.claude",
        "Install Claude CLI to monitor and manage your Claude Code sessions."
      )
    case .codex:
      return L10n.t(
        "cli_not_installed.message.codex",
        "Install Codex CLI to monitor and manage your Codex sessions."
      )
    case .pi:
      return L10n.t(
        "cli_not_installed.message.agentpi",
        "Install pi CLI to monitor and manage your AgentPi sessions."
      )
    }
  }

  private var installationURL: URL {
    CLIDetectionService.providerInstallURL(for: provider)
  }
}

#Preview("Claude Not Installed") {
  CLINotInstalledView(provider: .claude)
    .frame(width: 400, height: 400)
}

#Preview("Codex Not Installed") {
  CLINotInstalledView(provider: .codex)
    .frame(width: 400, height: 400)
}

#Preview("AgentPi Not Installed") {
  CLINotInstalledView(provider: .pi)
    .frame(width: 400, height: 400)
}
