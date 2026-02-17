//
//  MultiSessionLaunchView.swift
//  AgentPi
//
//  Always-visible session launcher for starting Claude, Codex, or AgentPi
//  with a shared prompt. Supports local mode and worktree mode.
//

#if canImport(AppKit)
import AppKit
#endif
import SwiftUI
import UniformTypeIdentifiers

// MARK: - MultiSessionLaunchView

public struct MultiSessionLaunchView: View {
  @Bindable var viewModel: MultiSessionLaunchViewModel
  var intelligenceViewModel: IntelligenceViewModel?
  var expandRequestID: Int = 0

  @AppStorage(AgentPiDefaults.smartModeEnabled) private var smartModeEnabled: Bool = false
  @AppStorage(AgentPiDefaults.uxGuidedHintsEnabled) private var uxGuidedHintsEnabled: Bool = true
  @AppStorage(AgentPiDefaults.uxExpertQuickMode) private var uxExpertQuickMode: Bool = false
  @AppStorage(AgentPiDefaults.launchPartialWhenCliMissing) private var launchPartialWhenCliMissing: Bool = true

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.openSettings) private var openSettings
  @State private var isExpanded = false
  @State private var isDragging = false
  @State private var showingFilePicker = false
  @State private var showingPlanSheet = false
  @State private var showFullSmartPlanningResponse = false

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      formHeader

      if isExpanded {
        Divider()

        if viewModel.isSmartModeAvailable && smartModeEnabled {
          launchModeToggle
        }

        repositorySection

        if viewModel.launchMode == .manual {
          readinessStrip
        }

        promptEditor

        if viewModel.launchMode == .manual {
          manualSelectionFeedback
        }

        if !viewModel.attachedFiles.isEmpty {
          attachedFilesSection
        }

        if viewModel.launchMode == .manual {
          if viewModel.selectedRepository != nil {
            workModeRow
          }

          providerPills

          if !missingProviderAvailabilities.isEmpty {
            cliAvailabilityBanner
          }

          if viewModel.isLaunching && viewModel.workMode == .worktree {
            progressSection
          }
        }

        if viewModel.launchMode == .smart {
          smartProviderPills

          switch viewModel.smartPhase {
          case .planning:
            smartPlanningSection
          case .planReady:
            smartPlanReviewSection
          case .launching:
            smartLaunchingSection
          case .idle:
            EmptyView()
          }
        }

        if let error = viewModel.launchError {
          errorView(error)
        }

        Divider()

        actionButtons
      }
    }
    .padding(DesignTokens.Spacing.md)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
        .fill(Color.surfaceOverlay)
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
        .stroke(isDragging ? Color.accentColor : Color.borderSubtle, lineWidth: isDragging ? 2 : 1)
    )
    .onDrop(
      of: [.fileURL, .png, .tiff, .image, .pdf],
      isTargeted: isExpanded ? $isDragging : .constant(false)
    ) { providers in
      guard isExpanded else { return false }
      handleDroppedFiles(providers)
      return true
    }
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: [.image, .pdf, .plainText, .data],
      allowsMultipleSelection: true
    ) { result in
      handlePickedFiles(result)
    }
    .sheet(isPresented: $showingPlanSheet) {
      SmartPlanDetailView(
        planText: viewModel.smartPlanText,
        plan: viewModel.smartOrchestrationPlan,
        onDismiss: { showingPlanSheet = false }
      )
    }
    .onChange(of: smartModeEnabled) { _, enabled in
      if !enabled {
        viewModel.launchMode = .manual
      }
    }
    .onChange(of: viewModel.isLaunching) { wasLaunching, isLaunching in
      if wasLaunching && !isLaunching && !viewModel.isSmartInteractive && viewModel.launchError == nil {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded = false
        }
      }
    }
    .onChange(of: expandRequestID) { _, _ in
      withAnimation(.easeInOut(duration: 0.2)) {
        isExpanded = true
      }
    }
  }

  // MARK: - Header

  private var formHeader: some View {
    HStack {
      Text(L10n.t("launch.header.title", "Start Session"))
        .font(.system(size: 14, weight: .bold, design: .monospaced))
      Spacer()
      Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      }) {
        Image(systemName: isExpanded ? "minus.circle" : "plus.circle")
          .font(.system(size: 16))
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        isExpanded.toggle()
      }
    }
    .padding(.top, 6)
    .padding(.bottom, 6)
    .padding(.leading, 6)
  }

  // MARK: - Launch Mode Toggle

  private var launchModeToggle: some View {
    HStack(spacing: 12) {
      launchModeButton(mode: .manual, label: L10n.t("launch.mode.manual", "Manual"), icon: nil)
      launchModeButton(mode: .smart, label: L10n.t("launch.mode.smart", "Smart"), icon: "sparkles", showsBetaBadge: true)
      Spacer()
    }
  }

  private func launchModeButton(
    mode: LaunchMode,
    label: String,
    icon: String?,
    showsBetaBadge: Bool = false
  ) -> some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.launchMode = mode
      }
    }) {
      HStack(spacing: 4) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 10))
        }
        Text(label)
          .font(.system(size: 11, weight: viewModel.launchMode == mode ? .bold : .regular))
        if showsBetaBadge {
          Text(L10n.t("launch.mode.beta", "Beta"))
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(viewModel.launchMode == mode ? .brandPrimary : .secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
              Capsule()
                .fill(viewModel.launchMode == mode ? Color.brandPrimary.opacity(0.15) : Color.primary.opacity(0.06))
            )
        }
      }
      .foregroundColor(viewModel.launchMode == mode ? .primary : .secondary.opacity(0.6))
      .fixedSize()
    }
    .buttonStyle(.plain)
  }

  // MARK: - Repository Section

  private var repositorySection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        if viewModel.selectedRepository != nil {
          HStack(spacing: 8) {
            Button(action: { viewModel.selectRepository() }) {
              HStack(spacing: 6) {
                Image(systemName: "folder")
                  .font(.system(size: 11))
                Text(viewModel.selectedRepository?.name ?? L10n.t("launch.repo.select", "Select repository"))
                  .font(.system(size: 12, weight: .medium))
              }
            }
            .buttonStyle(.plain)

            Button(action: {
              withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.clearSelectedRepository()
              }
            }) {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            Capsule()
              .fill(viewModel.selectedRepository != nil
                    ? Color.primary.opacity(0.1)
                    : Color.primary.opacity(0.05))
          )
          .overlay(
            Capsule()
              .stroke(Color.borderSubtle, lineWidth: 1)
          )
        } else {
          Button(action: { viewModel.selectRepository() }) {
            HStack(spacing: 6) {
              Image(systemName: "folder")
                .font(.system(size: 11))
              Text(L10n.t("launch.repo.select", "Select repository"))
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(Color.primary.opacity(0.05))
            )
            .overlay(
              Capsule()
                .stroke(Color.borderSubtle, lineWidth: 1)
            )
          }
          .buttonStyle(.plain)
        }

        Button(action: { showingFilePicker = true }) {
          HStack(spacing: 6) {
            Image(systemName: "paperclip")
              .font(.system(size: 11))
            Text(L10n.t("launch.attach_files", "Attach files"))
              .font(.system(size: 12, weight: .medium))
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            Capsule()
              .fill(Color.primary.opacity(0.05))
          )
          .overlay(
            Capsule()
              .stroke(Color.borderSubtle, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
      }

      if let repo = viewModel.selectedRepository {
        Text(repo.path)
          .font(.system(size: 10, design: .monospaced))
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
  }

  // MARK: - Prompt Editor

  private var promptEditor: some View {
    ZStack(alignment: .topLeading) {
      if viewModel.sharedPrompt.isEmpty {
        Text(promptPlaceholder)
          .font(.system(size: 12))
          .foregroundColor(.secondary.opacity(0.6))
          .padding(.leading, 7)
          .padding(.top, 4)
      }
      TextEditor(text: $viewModel.sharedPrompt)
        .font(.system(size: 12))
        .scrollContentBackground(.hidden)
        .padding(2)
    }
    .frame(minHeight: 60, maxHeight: 120)
    .padding(4)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color(NSColor.controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .stroke(Color.borderSubtle, lineWidth: 1)
    )
  }

  private var promptPlaceholder: String {
    LaunchCopyResolver.promptPlaceholder(for: copyState)
  }

  // MARK: - Readiness

  private var readinessStrip: some View {
    Group {
      if uxExpertQuickMode {
        HStack(spacing: 10) {
          ForEach(readinessItems) { item in
            VStack(spacing: 3) {
              Image(systemName: readinessIcon(for: item.state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(readinessColor(for: item.state))
              Text(item.title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
          }
          Spacer(minLength: 0)
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(readinessItems) { item in
            HStack(spacing: 7) {
              Image(systemName: readinessIcon(for: item.state))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(readinessColor(for: item.state))
              Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
              Text(item.message)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
              Spacer(minLength: 4)
              if let actionTitle = item.actionTitle {
                Button(actionTitle) {
                  handleReadinessAction(item.action)
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.plain)
                .foregroundColor(.brandPrimary)
              }
            }
          }
        }
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.primary.opacity(0.04))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .stroke(Color.borderSubtle, lineWidth: 1)
    )
  }

  private var readinessItems: [LaunchReadinessItem] {
    LaunchCopyResolver.readinessItems(for: copyState)
  }

  private func readinessIcon(for state: LaunchReadinessState) -> String {
    switch state {
    case .completed: return "checkmark.circle.fill"
    case .missing: return "circle"
    case .error: return "exclamationmark.triangle.fill"
    }
  }

  private func readinessColor(for state: LaunchReadinessState) -> Color {
    switch state {
    case .completed: return .green
    case .missing: return .secondary
    case .error: return .orange
    }
  }

  private func handleReadinessAction(_ action: LaunchReadinessAction?) {
    guard let action else { return }
    switch action {
    case .selectRepository:
      viewModel.selectRepository()
    case .selectAgent:
      if !viewModel.isClaudeSelected {
        viewModel.claudeMode = .enabled
      }
    case .fixCLI:
      openSettings()
    }
  }

  // MARK: - Attachments

  private var attachedFilesSection: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(viewModel.attachedFiles) { file in
          HStack(spacing: 4) {
            Image(systemName: file.icon)
              .font(.system(size: 9))
            Text(file.displayName)
              .font(.system(size: 10))
              .lineLimit(1)
            Button(action: {
              withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.removeAttachedFile(file)
              }
            }) {
              Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(Color.primary.opacity(0.08))
          )
          .overlay(
            Capsule()
              .stroke(Color.borderSubtle, lineWidth: 1)
          )
          .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
          ))
        }
      }
    }
    .transition(.move(edge: .top).combined(with: .opacity))
  }

  // MARK: - File Handling

  private func handleDroppedFiles(_ providers: [NSItemProvider]) {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        _ = provider.loadObject(ofClass: URL.self) { url, error in
          guard let url = url, error == nil else { return }
          Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) {
              viewModel.addAttachedFile(url)
            }
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
        _ = provider.loadDataRepresentation(for: .png) { data, error in
          guard let data = data, error == nil else { return }
          Task { @MainActor in
            let tempURL = FileManager.default.temporaryDirectory
              .appendingPathComponent("screenshot_\(UUID().uuidString).png")
            do {
              try data.write(to: tempURL)
              withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.addAttachedFile(tempURL, isTemporary: true)
              }
            } catch {
              print("Failed to save dropped screenshot: \(error)")
            }
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
        _ = provider.loadDataRepresentation(for: .tiff) { data, error in
          guard let data = data, error == nil else { return }
          Task { @MainActor in
            let tempURL = FileManager.default.temporaryDirectory
              .appendingPathComponent("screenshot_\(UUID().uuidString).tiff")
            do {
              try data.write(to: tempURL)
              withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.addAttachedFile(tempURL, isTemporary: true)
              }
            } catch {
              print("Failed to save dropped screenshot: \(error)")
            }
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
        _ = provider.loadDataRepresentation(for: .image) { data, error in
          guard let data = data, error == nil else { return }
          Task { @MainActor in
            let tempURL = FileManager.default.temporaryDirectory
              .appendingPathComponent("dropped_image_\(UUID().uuidString).png")
            do {
              try data.write(to: tempURL)
              withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.addAttachedFile(tempURL, isTemporary: true)
              }
            } catch {
              print("Failed to save dropped image: \(error)")
            }
          }
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
        _ = provider.loadDataRepresentation(for: .pdf) { data, error in
          guard let data = data, error == nil else { return }
          Task { @MainActor in
            let tempURL = FileManager.default.temporaryDirectory
              .appendingPathComponent("dropped_document_\(UUID().uuidString).pdf")
            do {
              try data.write(to: tempURL)
              withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.addAttachedFile(tempURL, isTemporary: true)
              }
            } catch {
              print("Failed to save dropped PDF: \(error)")
            }
          }
        }
      }
    }
  }

  private func handlePickedFiles(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      withAnimation(.easeInOut(duration: 0.2)) {
        for url in urls {
          viewModel.addAttachedFile(url)
        }
      }
    case .failure(let error):
      print("File picker error: \(error.localizedDescription)")
    }
  }

  // MARK: - Work Mode Row

  private var workModeRow: some View {
    ViewThatFits(in: .horizontal) {
      // Primary: horizontal layout
      HStack(spacing: 0) {
        HStack(spacing: 12) {
          workModeButton(mode: .local, label: L10n.t("launch.mode.local", "Local"))
          workModeButton(mode: .worktree, label: L10n.t("launch.mode.worktree", "Worktree"))
        }
        Spacer()
        branchInfoView
      }
      // Fallback: vertical layout when horizontal doesn't fit
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          workModeButton(mode: .local, label: L10n.t("launch.mode.local", "Local"))
          workModeButton(mode: .worktree, label: L10n.t("launch.mode.worktree", "Worktree"))
        }
        branchInfoView
      }
    }
  }

  private func workModeButton(mode: WorkMode, label: String) -> some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.workMode = mode
      }
    }) {
      Text(label)
        .font(.system(size: 11, weight: viewModel.workMode == mode ? .bold : .regular))
        .foregroundColor(viewModel.workMode == mode ? .primary : .secondary.opacity(0.6))
        .fixedSize()
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var branchInfoView: some View {
    switch viewModel.workMode {
    case .local:
      HStack(spacing: 4) {
        Image(systemName: "arrow.triangle.branch")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
        if viewModel.isLoadingCurrentBranch {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 12, height: 12)
        } else {
          Text(viewModel.currentBranchName.isEmpty ? "—" : viewModel.currentBranchName)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
    case .worktree:
      if viewModel.isLoadingBranches {
        HStack(spacing: 4) {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 12, height: 12)
          Text(L10n.t("launch.loading", "Loading..."))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } else {
        Picker(L10n.t("launch.base_branch", "Base branch"), selection: $viewModel.baseBranch) {
          Text(L10n.t("launch.base_branch.current_head", "Current HEAD")).tag(nil as RemoteBranch?)
          ForEach(viewModel.availableBranches) { branch in
            Text(branch.displayName).tag(branch as RemoteBranch?)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
      }
    }
  }

  // MARK: - Provider Pills

  private var providerPills: some View {
    HStack(spacing: 8) {
      Text(L10n.t("launch.select_agent", "Select agent"))
        .font(.system(size: 11))
        .foregroundColor(.secondary)
      claudePill
      providerPill(
        label: "Codex",
        isSelected: $viewModel.isCodexSelected
      )
      providerPill(
        label: "AgentPi",
        isSelected: $viewModel.isPiSelected
      )

      if LaunchCopyResolver.sharedPromptBadgeVisible(for: copyState) {
        Text(L10n.t("launch.badge.shared_prompt", "Shared Prompt"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(Color.primary.opacity(0.06))
          )
      }

      Spacer()
    }
  }

  private var manualSelectionFeedback: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(LaunchCopyResolver.selectionStatusText(for: copyState))
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
        .lineLimit(1)

      if let hint = LaunchCopyResolver.worktreeHintText(for: copyState) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.triangle.branch")
            .font(.system(size: 9))
            .foregroundColor(.secondary)
          Text(hint)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
      }

      if uxGuidedHintsEnabled && !uxExpertQuickMode,
         let hint = LaunchCopyResolver.guidedHintText(for: copyState) {
        HStack(spacing: 4) {
          Image(systemName: "lightbulb")
            .font(.system(size: 9))
            .foregroundColor(.secondary)
          Text(hint)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
      }
    }
  }

  private var cliAvailabilityBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !launchableProviderLabels.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 10))
            .foregroundColor(.green)
          Text(
            L10n.f(
              "launch.cli.available_format",
              "Launchable: %@",
              launchableProviderLabels.joined(separator: L10n.t("launch.selection.separator", ", "))
            )
          )
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(1)
        }
      }

      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 10))
          .foregroundColor(.orange)
        HStack(spacing: 4) {
          Text(
            L10n.f(
              "launch.cli.missing_format",
              "Missing CLI: %@",
              missingProviderLabels.joined(separator: L10n.t("launch.selection.separator", ", "))
            )
          )
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(1)

          if !launchableProviderLabels.isEmpty {
            Text(L10n.t("launch.cli.skip_suffix", "(will skip)"))
              .font(.system(size: 10))
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }

      HStack(spacing: 8) {
        Button(L10n.t("launch.action.open_settings", "Open Settings")) {
          openSettings()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        if missingProviderAvailabilities.count == 1, let provider = missingProviderAvailabilities.first?.provider {
          Button(L10n.t("launch.action.install_guide", "Install Guide")) {
            openInstallGuide(for: provider)
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        } else {
          Menu(L10n.t("launch.action.install_guide", "Install Guide")) {
            ForEach(missingProviderAvailabilities, id: \.provider) { availability in
              Button(availability.provider.rawValue) {
                openInstallGuide(for: availability.provider)
              }
            }
          }
          .controlSize(.small)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.orange.opacity(0.1))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
    )
  }

  private func openInstallGuide(for provider: SessionProviderKind) {
    let url = CLIDetectionService.providerInstallURL(for: provider)
    #if canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
  }

  private var claudePill: some View {
    Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.claudeMode = viewModel.claudeMode.next
      }
    }) {
      Text(viewModel.claudeMode.label)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(claudePillForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
          Capsule()
            .fill(claudePillBackground)
        )
    }
    .buttonStyle(.plain)
  }

  private var claudePillForeground: Color {
    switch viewModel.claudeMode {
    case .disabled:
      return .secondary
    case .enabled:
      return colorScheme == .dark ? .black : .white
    case .enabledDangerously:
      return Color(nsColor: NSColor(srgbRed: 0.45, green: 0.1, blue: 0.1, alpha: 1))
    }
  }

  private var claudePillBackground: Color {
    switch viewModel.claudeMode {
    case .disabled:
      return Color.primary.opacity(0.06)
    case .enabled:
      return colorScheme == .dark ? Color.white : Color.black
    case .enabledDangerously:
      return colorScheme == .dark
        ? Color(nsColor: NSColor(srgbRed: 0.96, green: 0.64, blue: 0.64, alpha: 1))
        : Color(nsColor: NSColor(srgbRed: 0.91, green: 0.54, blue: 0.54, alpha: 1))
    }
  }

  private func providerPill(label: String, isSelected: Binding<Bool>) -> some View {
    Button(action: { isSelected.wrappedValue.toggle() }) {
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(isSelected.wrappedValue ? (colorScheme == .dark ? .black : .white) : .secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
          Capsule()
            .fill(isSelected.wrappedValue ? (colorScheme == .dark ? Color.white : Color.black) : Color.primary.opacity(0.06))
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Progress

  private var progressSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      if viewModel.isClaudeSelected {
        progressRow(label: "Claude", progress: viewModel.claudeProgress)
      }
      if viewModel.isCodexSelected {
        progressRow(label: "Codex", progress: viewModel.codexProgress)
      }
      if viewModel.isPiSelected {
        progressRow(label: "AgentPi", progress: viewModel.piProgress)
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.primary.opacity(0.03))
    )
  }

  private func progressRow(label: String, progress: WorktreeCreationProgress) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
        .frame(width: 40, alignment: .trailing)

      if progress.isInProgress {
        ProgressView(value: progress.progressValue)
          .tint(.primary)
      } else {
        Image(systemName: progress.icon)
          .font(.caption)
          .foregroundColor(progressIconColor(for: progress))
      }

      Text(progress.statusMessage)
        .font(.caption2)
        .foregroundColor(.secondary)
        .lineLimit(1)

      Spacer()

      if progress.isInProgress {
        Text("\(Int(progress.progressValue * 100))%")
          .font(.caption2)
          .foregroundColor(.secondary)
          .monospacedDigit()
      }
    }
  }

  private func progressIconColor(for progress: WorktreeCreationProgress) -> Color {
    switch progress {
    case .completed:
      return .green
    case .failed:
      return .red
    default:
      return .secondary
    }
  }

  // MARK: - Smart Provider Pills

  private var smartProviderPills: some View {
    HStack(spacing: 8) {
      Text(L10n.t("launch.select_agent", "Select agent"))
        .font(.system(size: 11))
        .foregroundColor(.secondary)
      ForEach(SmartProvider.allCases, id: \.self) { provider in
        smartProviderPill(provider: provider)
      }
      Spacer()
    }
  }

  private func smartProviderPill(provider: SmartProvider) -> some View {
    let isSelected = viewModel.smartProvider == provider
    return Button(action: {
      withAnimation(.easeInOut(duration: 0.2)) {
        viewModel.smartProvider = provider
      }
    }) {
      Text(provider.rawValue)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(isSelected ? (colorScheme == .dark ? .black : .white) : .secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
          Capsule()
            .fill(isSelected ? (colorScheme == .dark ? Color.white : Color.black) : Color.primary.opacity(0.06))
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Smart Phase Views

  private var smartPlanningSection: some View {
    let intelligence = intelligenceViewModel
    let toolSteps = intelligence?.toolSteps ?? []
    let completedCount = toolSteps.filter(\.isComplete).count

    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        ZStack {
          Circle()
            .fill(Color.brandPrimary.opacity(0.15))
            .frame(width: 24, height: 24)
          ProgressView()
            .scaleEffect(0.45)
            .tint(.brandPrimary)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.t("launch.smart.planning.title", "Building launch plan"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
          Text(L10n.t("launch.smart.planning.subtitle", "Exploring the repository and preparing execution steps"))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        Spacer(minLength: 8)

        Text(L10n.t("launch.smart.live", "Live"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.brandPrimary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(Color.brandPrimary.opacity(0.12))
          )

        Button(action: {
          viewModel.cancelSmartLaunch()
        }) {
          Text(L10n.t("launch.cancel", "Cancel"))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              Capsule()
                .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
      }

      if let intelligence, !intelligence.lastResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let hasOlderUpdates = hasExpandedPlanningResponse(intelligence.lastResponse)
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Label(L10n.t("launch.smart.latest_update", "Latest agent update"), systemImage: "text.bubble")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(.secondary)
            Spacer()
            if hasOlderUpdates {
              Button(showFullSmartPlanningResponse ? L10n.t("launch.smart.show_recent", "Show recent") : L10n.t("launch.smart.show_full", "Show full")) {
                withAnimation(.easeInOut(duration: 0.15)) {
                  showFullSmartPlanningResponse.toggle()
                }
              }
              .buttonStyle(.plain)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.brandPrimary)
            }
          }

          Text(showFullSmartPlanningResponse
            ? intelligence.lastResponse
            : recentPlanningResponse(intelligence.lastResponse))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(1.5)
            .lineLimit(showFullSmartPlanningResponse ? nil : 5)
        }
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .fill(Color.primary.opacity(0.04))
        )
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Label(L10n.t("launch.smart.activity", "Activity"), systemImage: "list.bullet.rectangle.portrait")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
          Spacer()
          Text(L10n.f("launch.smart.activity_complete", "%d/%d complete", completedCount, toolSteps.count))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .monospacedDigit()
        }

        if toolSteps.isEmpty {
          Text(L10n.t("launch.smart.waiting_first_step", "Waiting for the first exploration step..."))
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(toolSteps) { step in
                  toolStepRow(step)
                }
                Color.clear
                  .frame(height: 1)
                  .id(smartToolFeedBottomID)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task(id: toolSteps.count) {
              guard !toolSteps.isEmpty else { return }
              withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(smartToolFeedBottomID, anchor: .bottom)
              }
            }
          }
          .frame(maxHeight: 240)
        }
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
          .fill(Color.primary.opacity(0.04))
      )
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.primary.opacity(0.03))
    )
    .onChange(of: viewModel.smartPhase) { _, phase in
      if phase != .planning {
        showFullSmartPlanningResponse = false
      }
    }
  }

  private func recentPlanningResponse(_ response: String) -> String {
    let paragraphs = response
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !paragraphs.isEmpty else { return response }
    return paragraphs.last ?? response
  }

  private func hasExpandedPlanningResponse(_ response: String) -> Bool {
    let recent = recentPlanningResponse(response).trimmingCharacters(in: .whitespacesAndNewlines)
    let full = response.trimmingCharacters(in: .whitespacesAndNewlines)
    return full != recent
  }

  private var smartToolFeedBottomID: String {
    "smart-tool-feed-bottom"
  }

  private func toolStepStatusText(_ step: IntelligenceViewModel.ToolStep) -> String {
    step.isComplete ? L10n.t("launch.smart.step.done", "Done") : L10n.t("launch.smart.step.running", "Running")
  }

  private func toolStepStatusColor(_ step: IntelligenceViewModel.ToolStep) -> Color {
    step.isComplete ? .green : .brandPrimary
  }

  private func toolStepIconBackground(_ step: IntelligenceViewModel.ToolStep) -> Color {
    step.isComplete ? Color.green.opacity(0.15) : Color.brandPrimary.opacity(0.15)
  }

  private func toolStepRowBackground(_ step: IntelligenceViewModel.ToolStep) -> Color {
    step.isComplete ? Color.green.opacity(0.06) : Color.primary.opacity(0.03)
  }

  private func toolStepBorderColor(_ step: IntelligenceViewModel.ToolStep) -> Color {
    step.isComplete ? Color.green.opacity(0.25) : Color.primary.opacity(0.12)
  }

  private func toolStepStatusBackground(_ step: IntelligenceViewModel.ToolStep) -> Color {
    step.isComplete ? Color.green.opacity(0.15) : Color.brandPrimary.opacity(0.15)
  }

  private func toolStepStateIcon(_ step: IntelligenceViewModel.ToolStep) -> some View {
    Group {
      if step.isComplete {
        Image(systemName: "checkmark")
          .font(.system(size: 8, weight: .bold))
          .foregroundColor(.green)
      } else {
        ProgressView()
          .scaleEffect(0.35)
          .tint(.brandPrimary)
      }
    }
  }

  private func toolStepRow(_ step: IntelligenceViewModel.ToolStep) -> some View {
    HStack(alignment: .top, spacing: 8) {
      ZStack {
        Circle()
          .fill(toolStepIconBackground(step))
          .frame(width: 16, height: 16)
        toolStepStateIcon(step)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(step.toolName)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.primary.opacity(0.85))
            .lineLimit(1)
          Spacer(minLength: 8)
          Text(toolStepStatusText(step))
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(toolStepStatusColor(step))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              Capsule()
                .fill(toolStepStatusBackground(step))
            )
        }

        Text(step.summary)
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .lineLimit(2)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(toolStepRowBackground(step))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(toolStepBorderColor(step), lineWidth: 1)
    )
  }

  private var smartPlanReviewSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 10) {
        ZStack {
          Circle()
            .fill(Color.brandPrimary.opacity(0.15))
            .frame(width: 24, height: 24)
          Image(systemName: "doc.text.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.brandPrimary)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.t("launch.smart.plan_ready", "Plan ready"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)

          if let plan = viewModel.smartOrchestrationPlan {
            Text(L10n.f("launch.smart.plan_ready_count", "%d sessions prepared. Review before launching.", plan.sessions.count))
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          } else {
            Text(L10n.t("launch.smart.plan_generated", "Plan generated. Open details before launching."))
              .font(.system(size: 11))
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        Button(action: { showingPlanSheet = true }) {
          HStack(spacing: 4) {
            Image(systemName: "list.bullet.clipboard")
              .font(.system(size: 10))
            Text(L10n.t("launch.smart.view_plan", "View Plan"))
              .font(.system(size: 11, weight: .medium))
          }
        }
        .buttonStyle(.bordered)
        .disabled(!hasSmartPlanDetails)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "arrow.triangle.branch")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text(L10n.t("launch.base_branch", "Base branch"))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        if viewModel.isLoadingBranches {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 12, height: 12)
        } else {
          Picker("", selection: $viewModel.baseBranch) {
            Text(L10n.t("launch.base_branch.current_head", "Current HEAD")).tag(nil as RemoteBranch?)
            ForEach(viewModel.availableBranches) { branch in
              Text(branch.displayName).tag(branch as RemoteBranch?)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      HStack {
        Button(action: {
          viewModel.rejectSmartPlan()
        }) {
          Text(L10n.t("launch.smart.reject", "Reject"))
            .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)

        Spacer()

        Button(action: {
          Task {
            await viewModel.approveSmartPlan()
          }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 11))
            Text(L10n.t("launch.smart.approve_launch", "Approve & Launch"))
              .font(.system(size: 11, weight: .medium))
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(.primary)
      }
      .padding(.top, 2)
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.primary.opacity(0.03))
    )
  }

  private var hasSmartPlanDetails: Bool {
    !viewModel.smartPlanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || viewModel.smartOrchestrationPlan != nil
  }

  private var smartLaunchingSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        ZStack {
          Circle()
            .fill(Color.brandPrimary.opacity(0.15))
            .frame(width: 24, height: 24)
          ProgressView()
            .scaleEffect(0.45)
            .tint(.brandPrimary)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.t("launch.smart.launching_sessions", "Launching sessions"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
          Text(L10n.t("launch.smart.launching_subtitle", "Creating worktrees and starting selected agents"))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        Spacer()

        Button(action: {
          viewModel.cancelSmartLaunch()
        }) {
          Text(L10n.t("launch.cancel", "Cancel"))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              Capsule()
                .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
      }

      if viewModel.claudeProgress != .idle {
        progressRow(label: L10n.t("launch.mode.worktree", "Worktree"), progress: viewModel.claudeProgress)
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.primary.opacity(0.03))
    )
  }

  // MARK: - Error

  private func errorView(_ error: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundColor(.orange)
        Text(error)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(8)
      }

      if viewModel.canRetryFailedLaunch {
        HStack(spacing: 8) {
          Button(L10n.t("launch.error.retry", "Retry")) {
            Task { await viewModel.retryLaunch() }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.mini)

          if viewModel.canExtendTimeoutAndRetry {
            Button(L10n.t("launch.error.continue_wait_30s", "Continue Wait (+30s)")) {
              Task { await viewModel.retryLaunch(extendWorktreeTimeoutBy: 30) }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
          }

          Button(L10n.t("launch.cancel", "Cancel")) {
            viewModel.clearLaunchError()
          }
          .buttonStyle(.plain)
          .foregroundColor(.secondary)
        }
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
        .fill(Color.orange.opacity(0.1))
    )
  }

  // MARK: - Action Buttons

  private var actionButtons: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Button(L10n.t("launch.reset", "Reset")) {
          viewModel.reset()
        }
        .disabled(viewModel.isLaunching)

        Spacer()

        if !(viewModel.launchMode == .smart && viewModel.isSmartInteractive) {
          Button(action: {
            Task {
              await viewModel.launchSessions()
            }
          }) {
            HStack(spacing: 6) {
              if viewModel.isLaunching {
                ProgressView()
                  .scaleEffect(0.7)
              }
              Text(launchButtonTitle)
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.primary)
          .disabled(launchDisabledReason != nil || !viewModel.isValid || viewModel.isLaunching)
          .help(launchDisabledReason ?? "")
        }
      }

      if let reason = launchDisabledReason, !viewModel.isLaunching {
        HStack(spacing: 4) {
          Image(systemName: "info.circle")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text(reason)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }

      if let skippedMessage = skippedLaunchMessage, !viewModel.isLaunching {
        HStack(spacing: 4) {
          Image(systemName: "arrow.triangle.branch")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text(skippedMessage)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  private var launchButtonTitle: String {
    LaunchCopyResolver.launchButtonTitle(for: copyState, isLaunching: viewModel.isLaunching)
  }

  private var copyState: LaunchCopyState {
    LaunchCopyState(
      launchMode: viewModel.launchMode,
      workMode: viewModel.workMode,
      claudeMode: viewModel.claudeMode,
      isCodexSelected: viewModel.isCodexSelected,
      isPiSelected: viewModel.isPiSelected,
      hasRepository: viewModel.selectedRepository != nil,
      hasPromptText: !viewModel.sharedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      isLoadingBranches: viewModel.isLoadingBranches,
      hasBranchLoadError: viewModel.hasBranchLoadingError,
      launchableProviderLabels: launchableProviderLabels,
      missingProviderLabels: missingProviderLabels
    )
  }

  private var launchDisabledReason: String? {
    LaunchCopyResolver.launchDisabledReason(for: copyState)
  }

  private var selectedProviderAvailabilities: [CLIDetectionService.ProviderAvailability] {
    CLIDetectionService.detectProviderAvailabilities(providers: viewModel.selectedProviders)
  }

  private var missingProviderAvailabilities: [CLIDetectionService.ProviderAvailability] {
    selectedProviderAvailabilities.filter { !$0.isLaunchable }
  }

  private var launchableProviderAvailabilities: [CLIDetectionService.ProviderAvailability] {
    let launchable = selectedProviderAvailabilities.filter { $0.isLaunchable }
    if launchPartialWhenCliMissing {
      return launchable
    }
    return missingProviderAvailabilities.isEmpty ? launchable : []
  }

  private var launchableProviderLabels: [String] {
    launchableProviderAvailabilities.map { $0.provider.rawValue }
  }

  private var missingProviderLabels: [String] {
    missingProviderAvailabilities.map { $0.provider.rawValue }
  }

  private var skippedLaunchMessage: String? {
    guard viewModel.launchError == nil,
          !viewModel.isLaunching,
          !viewModel.lastSkippedProviders.isEmpty else {
      return nil
    }

    let skippedLabels = viewModel.lastSkippedProviders
      .map(\.rawValue)
      .joined(separator: L10n.t("launch.selection.separator", ", "))
    return L10n.f(
      "launch.result.skipped_format",
      "Started %d agents. Skipped %d missing CLI: %@.",
      viewModel.lastLaunchedProviders.count,
      viewModel.lastSkippedProviders.count,
      skippedLabels
    )
  }
}

// MARK: - SmartPlanDetailView

private struct SmartPlanDetailView: View {
  let planText: String
  let plan: OrchestrationPlan?
  let onDismiss: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      // Header
      header

      Divider()

      // Body
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
          MarkdownView(content: planText, includeScrollView: false)
            .padding(DesignTokens.Spacing.lg)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
            )

          Group {
            if let plan, !plan.sessions.isEmpty {
              // Sessions
              VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("launch.plan.sessions", "Sessions"))
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(.primary)

                ForEach(plan.sessions) { session in
                  sessionRow(session)
                }
              }
            } else {
              VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("launch.plan.sessions", "Sessions"))
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(.primary)
                Text(L10n.t("launch.plan.sessions_unparsed", "Structured session details were not parsed for this response."))
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(DesignTokens.Spacing.lg)
          .background(cardBackground)
          .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
              .stroke(Color.borderSubtle, lineWidth: 1)
          )
        }
        .padding(DesignTokens.Spacing.xl)
      }
      .background(Color.surfaceCanvas)

      Divider()

      // Footer
      footer
    }
    .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
           minHeight: 450, idealHeight: 650, maxHeight: .infinity)
    .onKeyPress(.escape) {
      onDismiss()
      return .handled
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      HStack(spacing: 8) {
        Image(systemName: "list.bullet.clipboard")
          .font(.title3)
          .foregroundColor(.brandPrimary)
        Text(L10n.t("launch.plan.title", "Orchestration Plan"))
          .font(.title3.weight(.semibold))
      }

      Spacer()

      Button(L10n.t("launch.close", "Close")) {
        onDismiss()
      }
    }
    .padding()
    .background(Color.surfaceElevated)
  }

  // MARK: - Session Row

  private func sessionRow(_ session: OrchestrationSession) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "arrow.triangle.branch")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 2) {
          Text(session.description)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.primary)

          HStack(spacing: 6) {
            Text(session.branchName)
              .font(.system(size: 10, design: .monospaced))
              .foregroundColor(.secondary)

            Text(session.sessionType.rawValue)
              .font(.system(size: 9, weight: .medium))
              .foregroundColor(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(
                Capsule()
                  .fill(Color.primary.opacity(0.06))
              )
          }
        }

        Spacer()
      }

      VStack(alignment: .leading, spacing: 6) {
        Divider()

        Text(L10n.t("launch.plan.agent_prompt", "Agent Prompt"))
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.secondary)
          .textCase(.uppercase)

        MarkdownView(content: session.prompt, includeScrollView: false)
          .textSelection(.enabled)
      }
      .padding(.top, 8)
      .padding(.leading, 18)
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      Spacer()

      Button(action: copyPlanContent) {
        HStack(spacing: 4) {
          Image(systemName: "doc.on.doc")
          Text(L10n.t("launch.copy", "Copy"))
        }
      }
      .buttonStyle(.bordered)
      .help(L10n.t("launch.copy.help", "Copy plan to clipboard"))
    }
    .padding()
    .background(Color.surfaceElevated)
  }

  // MARK: - Helpers

  private var cardBackground: Color {
    colorScheme == .dark ? Color(white: 0.08) : Color.white
  }

  private func copyPlanContent() {
    #if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(planText, forType: .string)
    #endif
  }
}
