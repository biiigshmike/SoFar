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

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - UBPresentationDetent (compat wrapper)
// On iOS 16+ / macOS 13+, this bridges to SwiftUI.PresentationDetent.
// On earlier OS versions, it’s a placeholder so the view still compiles;
// detents are simply ignored.
enum UBPresentationDetent: Equatable, Hashable {
    case medium
    case large
    case fraction(Double)

    #if os(iOS) || targetEnvironment(macCatalyst)
    @available(iOS 16.0, *)
    var systemDetent: PresentationDetent {
        switch self {
        case .medium: return .medium
        case .large: return .large
        case .fraction(let v): return .fraction(v)
        }
    }
    #endif
}

// MARK: - EditSheetScaffold
struct EditSheetScaffold<Content: View>: View {

    // MARK: Inputs
    let title: String
    // Use compatibility detents so the type is available on older OSes.
    let detents: [UBPresentationDetent]
    let saveButtonTitle: String
    let cancelButtonTitle: String
    let isSaveEnabled: Bool
    var onCancel: (() -> Void)?
    var onSave: () -> Bool
    @ViewBuilder var content: Content

    // MARK: Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // Selection state for detents (compat type)
    #if os(iOS) || targetEnvironment(macCatalyst)
    @State private var detentSelection: UBPresentationDetent
    #endif

    // MARK: Init
    init(
        title: String,
        // Default detents mapped to compat type
        detents: [UBPresentationDetent] = [.medium, .large],
        initialDetent: UBPresentationDetent? = nil,
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
        navigationContainer {
            formContent
                .navigationTitle(title)
                .toolbar {
                    // Cancel
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelButtonTitle) {
                            onCancel?()
                            dismiss()
                        }
                        .tint(themeManager.selectedTheme.tint)
                    }
                    // Save
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveButtonTitle) {
                            if onSave() { dismiss() }
                        }
                        .tint(themeManager.selectedTheme.tint)
                        .disabled(!isSaveEnabled)
                    }
                }
        }
        .ub_navigationGlassBackground(
            baseColor: themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
        .accentColor(themeManager.selectedTheme.tint)
        .tint(themeManager.selectedTheme.tint)
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
        // MARK: Standard sheet behavior (platform-aware)
        .applyDetentsIfAvailable(detents: detents, selection: detentSelectionBinding)
        #if os(macOS)
        .frame(minWidth: 680)
        #endif
        .ub_sheetPadding()
    }

    // MARK: - Subviews

    // Navigation container: NavigationStack on iOS 16+/macOS 13+, else NavigationView
    @ViewBuilder
    private func navigationContainer<Inner: View>(@ViewBuilder content: () -> Inner) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
        }
    }

    // The form body with shared styling
    @ViewBuilder
    private var formContent: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            Form { content }
                .scrollContentBackground(.hidden)
                .listRowBackground(rowBackground)
                .ub_glassBackground(
                    themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .ub_formStyleGrouped()
                .ub_hideScrollIndicators()
                .multilineTextAlignment(.leading)
        } else {
            Form { content }
                .listRowBackground(rowBackground)
                .ub_glassBackground(
                    themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .ub_formStyleGrouped()
                .ub_hideScrollIndicators()
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: Row Background
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(themeManager.selectedTheme.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(separatorColor, lineWidth: 1)
            )
    }

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

    // MARK: Detent selection binding (iOS only)
    #if os(iOS) || targetEnvironment(macCatalyst)
    private var detentSelectionBinding: Binding<UBPresentationDetent>? { $detentSelection }
    #else
    private var detentSelectionBinding: Binding<UBPresentationDetent>? { nil }
    #endif
}

// MARK: - Detents application helper
private extension View {
    // Applies presentationDetents and drag indicator only on iOS 16+.
    func applyDetentsIfAvailable(
        detents: [UBPresentationDetent],
        selection: Binding<UBPresentationDetent>?
    ) -> some View {
        #if os(iOS) || targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *) {
            // Map compat detents to system detents
            let systemDetents = Set(detents.map { $0.systemDetent })
            if let selection {
                // Bridge the selection binding by mapping to/from system detents
                let bridged = Binding<PresentationDetent>(
                    get: { selection.wrappedValue.systemDetent },
                    set: { newValue in
                        // Reverse-map the system detent back to UBPresentationDetent
                        let mapped: UBPresentationDetent
                        switch newValue {
                        case .medium: mapped = .medium
                        case .large: mapped = .large
                        default:
                            // Fraction detents aren’t equatable by value; default to medium.
                            mapped = .medium
                        }
                        selection.wrappedValue = mapped
                    }
                )
                return AnyView(
                    self
                        .presentationDetents(systemDetents, selection: bridged)
                        .presentationDragIndicator(.visible)
                )
            } else {
                return AnyView(
                    self
                        .presentationDetents(systemDetents)
                        .presentationDragIndicator(.visible)
                )
            }
        } else {
            return AnyView(self)
        }
        #else
        return self
        #endif
    }
}
