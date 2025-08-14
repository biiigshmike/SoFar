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

// MARK: - UBEmptyState
/// Standardized empty-state presentation with optional action buttons.
struct UBEmptyState: View {

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
        maxMessageWidth: CGFloat = 520
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.onPrimaryTap = onPrimaryTap
        self.maxMessageWidth = maxMessageWidth
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
                Button(action: onPrimaryTap) {
                    Label(primaryButtonTitle, systemImage: "plus")
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.m)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain) // keep it neutral (no blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xl)
    }
}
