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

    // MARK: Environment
    @EnvironmentObject private var themeManager: ThemeManager

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
        .listRowBackground(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(themeManager.selectedTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .stroke(themeManager.selectedTheme.secondaryBackground, lineWidth: 1)
                )
        )
    }
}
