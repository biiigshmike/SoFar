//
//  UBFormSection.swift
//  SoFar
//
//  A reusable wrapper around SwiftUI's `Section` that unifies header
//  typography and spacing across iOS, iPadOS and macOS.  By using this
//  component instead of bare `Section` declarations, you ensure that
//  every form header uses a small caps footnote font with a secondary
//  color, matching the look of the Add Card form and other grouped
//  editors.  You can drop this into any `Form` to avoid rewriting
//  header modifiers repeatedly.
//
//  Usage:
//    UBFormSection("Preview") {
//        // your content here
//    }
//
//  The title parameter is required.  A footer can be supplied via
//  `footer` if needed.

import SwiftUI

/// A cross‑platform `Section` wrapper that standardises form headers.
/// - Parameters:
///   - title: The string to display above the section’s content.  The title
///     is rendered in a footnote font, with a secondary foreground color
///     and uppercased by default (to match Apple’s grouped forms).  If you
///     wish to disable automatic uppercase, set `isUppercased` to false.
///   - isUppercased: When true (default), the title is uppercased using
///     `.textCase(.uppercase)`.  Set to false to preserve the natural case.
///   - footer: Optional footer string displayed beneath the section.  This
///     text uses the platform’s default styling for footers.
///   - content: A `ViewBuilder` closure producing the section’s body.
struct UBFormSection<Content: View>: View {

    // MARK: Inputs
    private let title: String
    private let isUppercased: Bool
    private let footer: String?
    @ViewBuilder private var content: Content

    // MARK: Init
    init(_ title: String,
         isUppercased: Bool = true,
         footer: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.isUppercased = isUppercased
        self.footer = footer
        self.content = content()
    }

    // MARK: Body
    var body: some View {
        Section {
            content
        } header: {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(isUppercased ? .uppercase : nil)
        } footer: {
            if let footer = footer {
                Text(footer)
            }
        }
    }
}

// MARK: - Convenience Modifiers
extension View {
    /// Removes the default grouped form background from a section row and normalises padding.
    /// - Parameters:
    ///   - horizontalInset: Leading/trailing padding applied to the row. Defaults to the standard form inset.
    ///   - verticalInset: Top/bottom padding applied to the row. Defaults to a small system-friendly value.
    /// - Returns: A view with a clear row background and consistent insets, ideal for chip rows or custom containers.
    func ub_formSectionClearBackground(
        horizontalInset: CGFloat = DS.Spacing.l,
        verticalInset: CGFloat = DS.Spacing.s
    ) -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(
                EdgeInsets(
                    top: verticalInset,
                    leading: horizontalInset,
                    bottom: verticalInset,
                    trailing: horizontalInset
                )
            )
    }
}
