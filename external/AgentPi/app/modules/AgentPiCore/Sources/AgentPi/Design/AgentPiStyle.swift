//
//  AgentPiStyle.swift
//  AgentPi
//
//  Created by Assistant on 1/13/26.
//

import SwiftUI

public enum AgentPiLayout {
  public static let panelCornerRadius: CGFloat = 16
  public static let cardCornerRadius: CGFloat = 12
  public static let rowCornerRadius: CGFloat = 10
  public static let chipCornerRadius: CGFloat = 8
}

private struct AgentPiPanelModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.runtimeTheme) private var runtimeTheme

  func body(content: Content) -> some View {
    let defaultBackground = colorScheme == .dark ? Color.black : Color.white
    let backgroundColor = runtimeTheme?.hasCustomBackgrounds == true
      ? Color.adaptiveBackground(for: colorScheme, theme: runtimeTheme)
      : defaultBackground

    return content
      .background(
        RoundedRectangle(cornerRadius: AgentPiLayout.panelCornerRadius, style: .continuous)
          .fill(backgroundColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AgentPiLayout.panelCornerRadius, style: .continuous)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      )
  }
}

private struct AgentPiCardModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let isHighlighted: Bool

  func body(content: Content) -> some View {
    // Simple black/white background
    let backgroundColor = colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.98)
    let strokeColor = isHighlighted
      ? Color.brandPrimary.opacity(0.6)
      : Color.secondary.opacity(0.2)
    let strokeWidth: CGFloat = isHighlighted ? 2 : 1

    return content
      .background(
        RoundedRectangle(cornerRadius: AgentPiLayout.cardCornerRadius, style: .continuous)
          .fill(backgroundColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AgentPiLayout.cardCornerRadius, style: .continuous)
          .stroke(strokeColor, lineWidth: strokeWidth)
      )
  }
}

private struct AgentPiRowModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let isHighlighted: Bool

  func body(content: Content) -> some View {
    // Simple black/white background
    let backgroundColor = colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.96)
    let strokeColor = isHighlighted
      ? Color.brandPrimary.opacity(0.5)
      : Color.secondary.opacity(0.2)

    return content
      .background(
        RoundedRectangle(cornerRadius: AgentPiLayout.rowCornerRadius, style: .continuous)
          .fill(backgroundColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AgentPiLayout.rowCornerRadius, style: .continuous)
          .stroke(strokeColor, lineWidth: 1)
      )
  }
}

private struct AgentPiInsetModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    // Simple black/white background
    let backgroundColor = colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.94)

    return content
      .background(
        RoundedRectangle(cornerRadius: AgentPiLayout.rowCornerRadius, style: .continuous)
          .fill(backgroundColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AgentPiLayout.rowCornerRadius, style: .continuous)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      )
  }
}

private struct AgentPiChipModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let isActive: Bool

  func body(content: Content) -> some View {
    // Simple black/white background
    let fillColor = isActive
      ? Color.brandPrimary.opacity(0.15)
      : (colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92))
    let strokeColor = isActive
      ? Color.brandPrimary.opacity(0.4)
      : Color.secondary.opacity(0.25)

    return content
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: AgentPiLayout.chipCornerRadius, style: .continuous)
          .fill(fillColor)
      )
      .overlay(
        RoundedRectangle(cornerRadius: AgentPiLayout.chipCornerRadius, style: .continuous)
          .stroke(strokeColor, lineWidth: 1)
      )
  }
}

private struct AgentPiFlatRowModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme
  let isHighlighted: Bool
  let providerKind: SessionProviderKind?

  func body(content: Content) -> some View {
    // Always show subtle background, selection indicated only by left border
    let backgroundColor = colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.92)
    let accentColor: Color = if let provider = providerKind {
      Color.brandPrimary(for: provider)
    } else {
      Color.brandPrimary
    }

    return content
      .background(backgroundColor)
      .overlay(alignment: .leading) {
        // Left accent bar for highlighted state only
        if isHighlighted {
          Rectangle()
            .fill(accentColor)
            .frame(width: 2)
        }
      }
  }
}

public extension View {
  func agentPiPanel() -> some View {
    modifier(AgentPiPanelModifier())
  }

  func agentPiCard(isHighlighted: Bool = false) -> some View {
    modifier(AgentPiCardModifier(isHighlighted: isHighlighted))
  }

  func agentPiRow(isHighlighted: Bool = false) -> some View {
    modifier(AgentPiRowModifier(isHighlighted: isHighlighted))
  }

  func agentPiInset() -> some View {
    modifier(AgentPiInsetModifier())
  }

  func agentPiChip(isActive: Bool = false) -> some View {
    modifier(AgentPiChipModifier(isActive: isActive))
  }

  func agentPiFlatRow(isHighlighted: Bool = false, providerKind: SessionProviderKind? = nil) -> some View {
    modifier(AgentPiFlatRowModifier(isHighlighted: isHighlighted, providerKind: providerKind))
  }
}
