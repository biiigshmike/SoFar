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
    
#if os(macOS)
@State private var previousTextFieldAlignment: NSTextAlignment? = nil
#endif


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
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(themeManager.selectedTheme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(themeManager.selectedTheme.secondaryBackground, lineWidth: 1)
                            )
                    )
                    .background(themeManager.selectedTheme.background)
                    .navigationTitle(title)
                    .toolbar {
                        // MARK: Cancel
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelButtonTitle) {
                                onCancel?()
                                dismiss()
                            }
                            .tint(themeManager.selectedTheme.accent)
                        }
                        // MARK: Save
                        ToolbarItem(placement: .confirmationAction) {
                            Button(saveButtonTitle) {
                                if onSave() { dismiss() }
                            }
                            .tint(themeManager.selectedTheme.accent)
                            .disabled(!isSaveEnabled)
                        }
                    }
            } else {
                Form { content }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(themeManager.selectedTheme.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(themeManager.selectedTheme.secondaryBackground, lineWidth: 1)
                            )
                    )
                    .background(themeManager.selectedTheme.background)
                    .navigationTitle(title)
                    .toolbar {
                        // MARK: Cancel
                        ToolbarItem(placement: .cancellationAction) {
                            Button(cancelButtonTitle) {
                                onCancel?()
                                dismiss()
                            }
                            .tint(themeManager.selectedTheme.accent)
                        }
                        // MARK: Save
                        ToolbarItem(placement: .confirmationAction) {
                            Button(saveButtonTitle) {
                                if onSave() { dismiss() }
                            }
                            .tint(themeManager.selectedTheme.accent)
                            .disabled(!isSaveEnabled)
                        }
                    }
            }
        }
        // Ensure embedded forms respect the selected theme on all platforms.
        .accentColor(themeManager.selectedTheme.accent)
        .tint(themeManager.selectedTheme.accent)
        .background(themeManager.selectedTheme.background)
        // MARK: Standard sheet behavior (platform-aware)
        #if os(iOS) || targetEnvironment(macCatalyst)
        .presentationDetents(Set(detents), selection: $detentSelection)
        .presentationDragIndicator(.visible)
        #endif
        #if os(macOS)
        .frame(minWidth: 680)
        #endif
    }
}
