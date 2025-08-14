//
//  AppNavigationBarStyle.swift
//  SoFar
//
//  Cross-platform navigation toolbar styling + API.
//  Matches the Cards view look (plain black SF Symbols, no circles),
//  with consistent sizing, spacing, and accessibility.
//
//  Usage in a View:
//  .appToolbar(
//      titleDisplayMode: .large,
//      trailingItems: [
//          .add { onAdd() },
//          .edit { onEdit() },
//          .delete { onDelete() }
//      ]
//  )
//

import SwiftUI

// MARK: - UBTitleDisplayMode (Cross-Platform)
/// Cross-platform title display mode (macOS ignores `.large` and treats as `.automatic`).
enum UBTitleDisplayMode {
    case automatic
    case inline
    case large
}

// MARK: - AppNavBarTokens
/// Design tokens that control the appearance/spacing of toolbar icons.
enum AppNavBarTokens {
    /// Icon size for SF Symbols.
    static let iconPointSize: CGFloat = 20
    /// Weight for the icons.
    static let iconWeight: Font.Weight = .semibold
    /// Minimum tappable hit area.
    static let tapArea: CGSize = .init(width: 44, height: 44)
    /// Spacing between trailing items.
    static let trailingSpacing: CGFloat = 12
    /// Tint color for icons. `.primary` renders black in light mode, white in dark.
    static let iconTint: Color = .primary
}

// MARK: - AppToolbarItem
/// Declarative description of a toolbar button.
struct AppToolbarItem: Identifiable {
    let id = UUID()
    let systemName: String
    let accessibilityLabel: String
    let role: ButtonRole?
    let action: () -> Void

    // MARK: init(systemName:accessibilityLabel:role:action:)
    /// Initializes a toolbar item.
    /// - Parameters:
    ///   - systemName: SF Symbol name.
    ///   - accessibilityLabel: VoiceOver label.
    ///   - role: Optional role (e.g., `.destructive`).
    ///   - action: Action when tapped.
    init(systemName: String,
         accessibilityLabel: String,
         role: ButtonRole? = nil,
         action: @escaping () -> Void) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.role = role
        self.action = action
    }
}

// MARK: - AppToolbarItem Builders
extension AppToolbarItem {
    // MARK: add(action:)
    /// Standard '+' button. Call when you need an add affordance.
    static func add(action: @escaping () -> Void) -> AppToolbarItem {
        AppToolbarItem(systemName: "plus", accessibilityLabel: "Add", action: action)
    }
    // MARK: edit(action:)
    /// Standard 'pencil' button.
    static func edit(action: @escaping () -> Void) -> AppToolbarItem {
        AppToolbarItem(systemName: "pencil", accessibilityLabel: "Edit", action: action)
    }
    // MARK: delete(action:)
    /// Standard 'trash' button. Uses destructive role for consistency.
    static func delete(action: @escaping () -> Void) -> AppToolbarItem {
        AppToolbarItem(systemName: "trash", accessibilityLabel: "Delete", role: .destructive, action: action)
    }
    // MARK: custom(systemName:accessibilityLabel:role:action:)
    /// Custom SF Symbol.
    static func custom(systemName: String,
                       accessibilityLabel: String,
                       role: ButtonRole? = nil,
                       action: @escaping () -> Void) -> AppToolbarItem {
        AppToolbarItem(systemName: systemName, accessibilityLabel: accessibilityLabel, role: role, action: action)
    }
}

// MARK: - AppToolbarIcon (Visual)
private struct AppToolbarIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: AppNavBarTokens.iconPointSize,
                          weight: AppNavBarTokens.iconWeight,
                          design: .rounded))
            .frame(width: AppNavBarTokens.tapArea.width,
                   height: AppNavBarTokens.tapArea.height)
            .contentShape(Rectangle())
            .foregroundStyle(AppNavBarTokens.iconTint)
            .accessibilityHidden(true)
    }
}

// MARK: - AppToolbarButton (Behavior)
private struct AppToolbarButton: View {
    let item: AppToolbarItem
    var body: some View {
        Button(role: item.role, action: item.action) {
            AppToolbarIcon(systemName: item.systemName)
        }
        .buttonStyle(.plain)          // no circles; matches Cards
        .tint(AppNavBarTokens.iconTint)
        .accessibilityLabel(Text(item.accessibilityLabel))
        .help(item.accessibilityLabel)
    }
}

// MARK: - Private helpers (Cross-Platform title mode)
private extension View {
    // MARK: ub_applyTitleDisplayMode(_:)
    /// Applies the desired title display mode using platform-appropriate APIs.
    @ViewBuilder
    func ub_applyTitleDisplayMode(_ mode: UBTitleDisplayMode) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
            switch mode {
            case .inline:     self.toolbarTitleDisplayMode(.inline)
            case .large:      self.toolbarTitleDisplayMode(.large)
            case .automatic:  self.toolbarTitleDisplayMode(.automatic)
            }
        } else {
            switch mode {
            case .inline:     self.navigationBarTitleDisplayMode(.inline)
            case .large:      self.navigationBarTitleDisplayMode(.large)
            case .automatic:  self.navigationBarTitleDisplayMode(.automatic)
            }
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            // macOS doesn't have "large" – map it to automatic.
            switch mode {
            case .inline:     self.toolbarTitleDisplayMode(.inline)
            case .large:      self.toolbarTitleDisplayMode(.automatic)
            case .automatic:  self.toolbarTitleDisplayMode(.automatic)
            }
        } else {
            self // no-op on older macOS
        }
        #else
        self
        #endif
    }
}

// MARK: - AppToolbarModifier
private struct AppToolbarModifier: ViewModifier {
    let titleDisplayMode: UBTitleDisplayMode
    let leadingItems: [AppToolbarItem]
    let trailingItems: [AppToolbarItem]

    // MARK: body(content:)
    func body(content: Content) -> some View {
        content
            .ub_applyTitleDisplayMode(titleDisplayMode)
            .toolbar {
                // Leading
                if !leadingItems.isEmpty {
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            ForEach(leadingItems) { AppToolbarButton(item: $0) }
                        }
                    } else {
                        ToolbarItemGroup(placement: .navigationBarLeading) {
                            ForEach(leadingItems) { AppToolbarButton(item: $0) }
                        }
                    }
                    #elseif os(macOS)
                    // Best match on macOS for "leading" area.
                    ToolbarItemGroup(placement: .navigation) {
                        ForEach(leadingItems) { AppToolbarButton(item: $0) }
                    }
                    #else
                    ToolbarItemGroup(placement: .automatic) {
                        ForEach(leadingItems) { AppToolbarButton(item: $0) }
                    }
                    #endif
                }

                // Trailing
                if !trailingItems.isEmpty {
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    if #available(iOS 16.0, tvOS 16.0, visionOS 1.0, *) {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            HStack(spacing: AppNavBarTokens.trailingSpacing) {
                                ForEach(trailingItems) { AppToolbarButton(item: $0) }
                            }
                        }
                    } else {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            HStack(spacing: AppNavBarTokens.trailingSpacing) {
                                ForEach(trailingItems) { AppToolbarButton(item: $0) }
                            }
                        }
                    }
                    #elseif os(macOS)
                    // Best match on macOS for "trailing" group is primaryAction.
                    ToolbarItemGroup(placement: .primaryAction) {
                        HStack(spacing: AppNavBarTokens.trailingSpacing) {
                            ForEach(trailingItems) { AppToolbarButton(item: $0) }
                        }
                    }
                    #else
                    ToolbarItemGroup(placement: .automatic) {
                        HStack(spacing: AppNavBarTokens.trailingSpacing) {
                            ForEach(trailingItems) { AppToolbarButton(item: $0) }
                        }
                    }
                    #endif
                }
            }
    }
}

// MARK: - View API
extension View {
    // MARK: appToolbar(titleDisplayMode:leadingItems:trailingItems:)
    /// Attaches the standard So Far toolbar to the view.
    /// - Parameters:
    ///   - titleDisplayMode: `.large`, `.inline`, or `.automatic` (macOS maps `.large`→`.automatic`)
    ///   - leadingItems: Buttons on the leading/navigation area
    ///   - trailingItems: Buttons on the trailing/primary action area
    func appToolbar(
        titleDisplayMode: UBTitleDisplayMode = .large,
        leadingItems: [AppToolbarItem] = [],
        trailingItems: [AppToolbarItem] = []
    ) -> some View {
        modifier(AppToolbarModifier(
            titleDisplayMode: titleDisplayMode,
            leadingItems: leadingItems,
            trailingItems: trailingItems
        ))
    }
}
