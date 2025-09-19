//
//  EditSheetScaffold.swift
//  SoFar
//
//  A reusable, cross-platform scaffold for editing sheets.
//  Standardizes:
//  - Navigation title
//  - Cancel / Save buttons (toolbar placements map correctly on iOS & macOS)
//  - Presentation detents & drag indicator on iOS/iPadOS
//  - Form container with consistent spacing
//
//  Usage:
//  EditSheetScaffold(
//      title: "Rename Card",
//      detents: [.fraction(0.25), .medium],           // optional override
//      initialDetent: .medium,                        // optional
//      saveButtonTitle: "Save",                        // optional
//      cancelButtonTitle: "Cancel",                    // optional
//      isSaveEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
//      onCancel: { /* optional cleanup */ },
//      onSave: {                                      // return true to dismiss, false to stay open
//          /* validate & persist */; return true
//      }
//  ) {
//      // Your form content here
//  }
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - EditSheetScaffold
/// Generic wrapper that provides a consistent edit sheet layout and controls.
/// - Parameters:
///   - title: Title shown in the navigation bar.
///   - detents: Preferred sheet sizes on platforms that support them (iOS/iPadOS).
///   - initialDetent: The detent the sheet should open at. Defaults to the largest provided.
///   - saveButtonTitle / cancelButtonTitle: Localized labels for actions.
///   - isSaveEnabled: Enables/disables the Save button for validation UI.
///   - onCancel: Called when Cancel is tapped (sheet always dismisses).
///   - onSave: Return `true` to dismiss the sheet, `false` to keep it open (e.g., validation failed).
///   - content: The form/body of your editor.
struct EditSheetScaffold<Content: View>: View {
    


    // MARK: Inputs
    let title: String
    let detents: [PresentationDetent]
    let saveButtonTitle: String
    let cancelButtonTitle: String
    let isSaveEnabled: Bool
    var onCancel: (() -> Void)?
    var onSave: () -> Bool
    @ViewBuilder var content: Content

    // MARK: Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
#if os(iOS) || targetEnvironment(macCatalyst)
    @State private var detentSelection: PresentationDetent
#endif

    // MARK: Init
    init(
        title: String,
        detents: [PresentationDetent] = [.medium, .large],
        initialDetent: PresentationDetent? = nil,
        saveButtonTitle: String = "Save",
        cancelButtonTitle: String = "Cancel",
        isSaveEnabled: Bool = true,
        onCancel: (() -> Void)? = nil,
        onSave: @escaping () -> Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detents = detents
        self.saveButtonTitle = saveButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.isSaveEnabled = isSaveEnabled
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content()
#if os(iOS) || targetEnvironment(macCatalyst)
        _detentSelection = State(initialValue: initialDetent ?? detents.last ?? .medium)
#endif
    }

    // MARK: body
    var body: some View {
        NavigationStack {
            if #available(iOS 16.0, macOS 13.0, *) {
                Form { content }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(rowBackground)
                    .ub_glassBackground(
                        themeManager.selectedTheme.background,
                        configuration: themeManager.glassConfiguration
                    )
                    .ub_formStyleGrouped()
                    .ub_hideScrollIndicators()
                    .multilineTextAlignment(.leading)
                    .navigationTitle(title)
                    .toolbar {
                        // MARK: Cancel
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelButtonTitle) {
                                onCancel?()
                                dismiss()
                            }
                            .tint(themeManager.selectedTheme.tint)
                        }
                        // MARK: Save
                        ToolbarItem(placement: .confirmationAction) {
                            Button(saveButtonTitle) {
                                if onSave() { dismiss() }
                            }
                            .tint(themeManager.selectedTheme.tint)
                            .disabled(!isSaveEnabled)
                        }
                    }
            } else {
                Form { content }
                    .listRowBackground(rowBackground)
                    .ub_glassBackground(
                        themeManager.selectedTheme.background,
                        configuration: themeManager.glassConfiguration
                    )
                    .ub_formStyleGrouped()
                    .ub_hideScrollIndicators()
                    .multilineTextAlignment(.leading)
                    .navigationTitle(title)
                    .toolbar {
                        // MARK: Cancel
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelButtonTitle) {
                                onCancel?()
                                dismiss()
                            }
                            .tint(themeManager.selectedTheme.tint)
                        }
                        // MARK: Save
                        ToolbarItem(placement: .confirmationAction) {
                            Button(saveButtonTitle) {
                                if onSave() { dismiss() }
                            }
                            .tint(themeManager.selectedTheme.tint)
                            .disabled(!isSaveEnabled)
                        }
                    }
            }
        }
        // Ensure embedded forms respect the selected theme on all platforms.
        .accentColor(themeManager.selectedTheme.tint)
        .tint(themeManager.selectedTheme.tint)
        .ub_glassBackground(
            themeManager.selectedTheme.background,
            configuration: themeManager.glassConfiguration
        )
        // MARK: Standard sheet behavior (platform-aware)
        #if os(iOS) || targetEnvironment(macCatalyst)
        .presentationDetents(Set(detents), selection: $detentSelection)
        .presentationDragIndicator(.visible)
        #endif
        #if os(macOS)
        .frame(minWidth: 680)
        #endif
        .ub_sheetPadding()
    }

    // MARK: Row Background
    /// Provides a consistent background and border for form rows across themes.
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(themeManager.selectedTheme.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(separatorColor, lineWidth: 1)
            )
    }

    /// Platform-aware separator color used for row borders.
    private var separatorColor: Color {
#if canImport(UIKit)
        return Color(uiColor: .separator)
#elseif canImport(AppKit)
        if #available(macOS 10.14, *) {
            return Color(nsColor: .separatorColor)
        } else {
            return Color.primary.opacity(0.2)
        }
#else
        return Color.primary.opacity(0.2)
#endif
    }
}
