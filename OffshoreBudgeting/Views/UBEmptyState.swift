//
//  UBEmptyState.swift
//  SoFar
//
//  A reusable, app-standard empty state view.
//  Matches the Cards screen styling: centered icon, bold title,
//  supportive message, and a pill-shaped primary action.
//
//  Usage:
//  UBEmptyState(
//      iconSystemName: "creditcard",
//      title: "Cards",
//      message: "Add your credit/debit/store cards to track variable spending.",
//      primaryButtonTitle: "Add your first card",
//      onPrimaryTap: { /* present add flow */ }
//  )
//

import SwiftUI
import UIKit

// MARK: - UBEmptyState
/// Standardized empty-state presentation with optional action buttons.
struct UBEmptyState: View {

    @Environment(\.isOnboardingPresentation) private var isOnboardingPresentation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: Content
    /// SF Symbol name to display above the title.
    let iconSystemName: String
    /// Main headline text.
    let title: String
    /// Supporting copy below the title.
    let message: String

    // MARK: Actions
    /// Optional primary action button label; when nil, no button is shown.
    let primaryButtonTitle: String?
    /// Callback when the primary button is tapped.
    let onPrimaryTap: (() -> Void)?

    // MARK: Layout
    /// Optional width limit for message text; defaults to a comfortably readable width.
    let maxMessageWidth: CGFloat
    /// How the empty state content should align within its available container.
    /// Defaults to centered to preserve existing call sites.
    let containerAlignment: Alignment

    // MARK: init(...)
    /// Designated initializer.
    /// - Parameters:
    ///   - iconSystemName: SF Symbol name (e.g., "creditcard")
    ///   - title: Headline (e.g., "Cards")
    ///   - message: Supportive copy, 1–2 lines if possible
    ///   - primaryButtonTitle: Text for CTA; pass `nil` to omit
    ///   - onPrimaryTap: Closure invoked when CTA is tapped
    ///   - maxMessageWidth: Optional width limit for the message line-wrapping
    init(
        iconSystemName: String,
        title: String,
        message: String,
        primaryButtonTitle: String? = nil,
        onPrimaryTap: (() -> Void)? = nil,
        maxMessageWidth: CGFloat = 520,
        containerAlignment: Alignment = .center
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.onPrimaryTap = onPrimaryTap
        self.maxMessageWidth = maxMessageWidth
        self.containerAlignment = containerAlignment
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            // MARK: Icon
            Image(systemName: iconSystemName)
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)

            // MARK: Title
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(UBTypography.cardTitleStatic)
                .ub_cardTitleShadow()

            // MARK: Message
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: maxMessageWidth)

            // MARK: Primary CTA (optional)
            if let primaryButtonTitle, let onPrimaryTap {
                primaryButton(title: primaryButtonTitle, action: onPrimaryTap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: containerAlignment)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, resolvedVerticalPadding)
    }

    private var resolvedVerticalPadding: CGFloat {
        return verticalSizeClass == .compact ? DS.Spacing.s : DS.Spacing.m
    }

    private var onboardingTint: Color {
        themeManager.selectedTheme.resolvedTint
    }

    // MARK: Primary Button Helpers
    @ViewBuilder
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        let fallbackTint = isOnboardingPresentation ? onboardingTint : primaryButtonTint
        let glassTint = isOnboardingPresentation ? onboardingTint : primaryButtonGlassTint

        glassPrimaryButton(
            title: title,
            fallbackTint: fallbackTint,
            glassTint: glassTint,
            action: action
        )
    }

    @ViewBuilder
    private func legacyPrimaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            primaryButtonLabel(title: title)
        }
        .buttonStyle(.plain) // flat/plain (no rounded background on legacy)
        .tint(primaryButtonTint)
    }

    @ViewBuilder
    private func primaryButtonLabel(title: String) -> some View {
        Label(title, systemImage: "plus")
            .labelStyle(.titleAndIcon)
            .foregroundStyle(primaryButtonForegroundColor())
    }

    @ViewBuilder
    private func glassPrimaryButton(
        title: String,
        fallbackTint: Color,
        glassTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        if capabilities.supportsOS26Translucency, #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
            glassStyledPrimaryButton(title: title, glassTint: glassTint, action: action)
        } else {
            legacyPrimaryButton(title: title, action: action)
        }
    }

    @available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
    @ViewBuilder
    private func glassStyledPrimaryButton(
        title: String,
        glassTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryButtonForegroundColor())
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.m)
        }
        .tint(glassTint)
        .buttonStyle(.glass)
        .frame(maxWidth: 320)
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private func primaryButtonForegroundColor(isTintedBackground: Bool = false) -> Color {
        switch colorScheme {
        case .light:
            return .black
        default:
            return isTintedBackground ? .white : .primary
        }
    }

    private var primaryButtonTint: Color {
        themeManager.selectedTheme.resolvedTint
    }

    private var primaryButtonGlassTint: Color {
        themeManager.selectedTheme.glassPalette.accent
    }
}
