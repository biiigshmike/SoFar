//
//  UnifiedSwipeActions.swift
//  SoFar
//
//  Created by You, with love and consistency.
//  Cross-platform: iOS, iPadOS, macOS
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - UnifiedSwipeConfig
public struct UnifiedSwipeConfig {
    public var showsEditAction: Bool
    public var deleteTitle: String
    public var deleteSystemImageName: String
    public var deleteTint: Color?
    public var editTitle: String
    public var editSystemImageName: String
    public var editTint: Color?
    public var allowsFullSwipeToDelete: Bool
    public var playHapticOnDelete: Bool
    public var deleteAccessibilityID: String?
    public var editAccessibilityID: String?

    public init(
        showsEditAction: Bool = true,
        deleteTitle: String = "Delete",
        deleteSystemImageName: String = "trash",
        deleteTint: Color? = UnifiedSwipeConfig.defaultDeleteTint,
        editTitle: String = "Edit",
        editSystemImageName: String = "pencil",
        editTint: Color? = UnifiedSwipeConfig.defaultEditTint,
        allowsFullSwipeToDelete: Bool = true,
        playHapticOnDelete: Bool = true,
        deleteAccessibilityID: String? = "swipe_delete",
        editAccessibilityID: String? = "swipe_edit"
    ) {
        self.showsEditAction = showsEditAction
        self.deleteTitle = deleteTitle
        self.deleteSystemImageName = deleteSystemImageName
        self.deleteTint = deleteTint
        self.editTitle = editTitle
        self.editSystemImageName = editSystemImageName
        self.editTint = editTint
        self.allowsFullSwipeToDelete = allowsFullSwipeToDelete
        self.playHapticOnDelete = playHapticOnDelete
        self.deleteAccessibilityID = deleteAccessibilityID
        self.editAccessibilityID = editAccessibilityID
    }

    public static let standard = UnifiedSwipeConfig()
    public static let deleteOnly = UnifiedSwipeConfig(showsEditAction: false)

    // MARK: Platform Defaults
    static var defaultDeleteTint: Color {
        #if os(iOS)
        return Color(UIColor.systemRed)
        #elseif os(macOS)
        if #available(macOS 11.0, *) {
            return Color(nsColor: .systemRed)
        } else {
            return .red
        }
        #else
        return .red
        #endif
    }

    static var defaultEditTint: Color {
        #if os(iOS)
        return Color(UIColor.systemGray5)
        #elseif os(macOS)
        if #available(macOS 11.0, *) {
            if let dynamic = NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark
                    ? NSColor(calibratedWhite: 0.28, alpha: 1.0)
                    : NSColor(calibratedWhite: 0.92, alpha: 1.0)
            } {
                return Color(nsColor: dynamic)
            } else {
                return Color(nsColor: .systemGray)
            }
        } else {
            return Color.gray.opacity(0.35)
        }
        #else
        return Color.gray.opacity(0.35)
        #endif
    }
}

// MARK: - UnifiedSwipeCustomAction
public struct UnifiedSwipeCustomAction: Identifiable {
    public let id = UUID()
    public var title: String
    public var systemImageName: String
    public var tint: Color
    public var role: ButtonRole?
    public var accessibilityID: String?
    public var action: () -> Void

    public init(
        title: String,
        systemImageName: String,
        tint: Color = .accentColor,
        role: ButtonRole? = nil,
        accessibilityID: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImageName = systemImageName
        self.tint = tint
        self.role = role
        self.accessibilityID = accessibilityID
        self.action = action
    }
}

// MARK: - UnifiedSwipeActionsModifier
private struct UnifiedSwipeActionsModifier: ViewModifier {
    let config: UnifiedSwipeConfig
    let onEdit: (() -> Void)?
    let onDelete: () -> Void
    let customActions: [UnifiedSwipeCustomAction]

    func body(content: Content) -> some View {
        let base = content.contextMenu {
            if let onEdit, config.showsEditAction {
                Button { onEdit() } label: {
                    Label(config.editTitle, systemImage: config.editSystemImageName)
                }
                .help(config.editTitle)
                .accessibilityIdentifierIfAvailable(config.editAccessibilityID)
            }

            ForEach(customActions) { item in
                Button(role: item.role) { item.action() } label: {
                    Label(item.title, systemImage: item.systemImageName)
                }
                .tint(item.tint)
                .help(item.title)
                .accessibilityIdentifierIfAvailable(item.accessibilityID)
            }

            Divider()

            Button(role: .destructive) { triggerDelete() } label: {
                Label(config.deleteTitle, systemImage: config.deleteSystemImageName)
            }
            .help(config.deleteTitle)
            .accessibilityIdentifierIfAvailable(config.deleteAccessibilityID)
        }

        #if os(iOS)
        if #available(iOS 15.0, *) {
            base.swipeActions(edge: .trailing, allowsFullSwipe: config.allowsFullSwipeToDelete) {
                deleteButton()
                if let onEdit, config.showsEditAction { editButton(onEdit: onEdit) }
                customButtons()
            }
        } else {
            base
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            base.swipeActions(edge: .trailing) {
                deleteButton()
                if let onEdit, config.showsEditAction { editButton(onEdit: onEdit) }
                customButtons()
            }
        } else {
            base
        }
        #else
        base
        #endif
    }

    // MARK: Buttons
    @ViewBuilder
    private func deleteButton() -> some View {
        let tint = config.deleteTint ?? UnifiedSwipeConfig.defaultDeleteTint
        let foreground = tint.ub_contrastingForegroundColor

        Button(role: .destructive) {
            triggerDelete()
        } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.deleteTitle,
                systemImageName: config.deleteSystemImageName,
                iconOverride: foreground,
                textOverride: foreground
            )
        }
        .applySwipeActionTintIfNeeded(tint)
        .accessibilityIdentifierIfAvailable(config.deleteAccessibilityID)
    }

    @ViewBuilder
    private func editButton(onEdit: @escaping () -> Void) -> some View {
        let tint = config.editTint ?? UnifiedSwipeConfig.defaultEditTint
        let foreground = tint.ub_contrastingForegroundColor

        Button { onEdit() } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.editTitle,
                systemImageName: config.editSystemImageName,
                iconOverride: foreground,
                textOverride: foreground
            )
        }
        .applySwipeActionTintIfNeeded(tint)
        .accessibilityIdentifierIfAvailable(config.editAccessibilityID)
    }

    @ViewBuilder
    private func customButtons() -> some View {
        ForEach(customActions) { item in
            let foreground = item.tint.ub_contrastingForegroundColor

            Button(role: item.role) { item.action() } label: {
                UnifiedSwipeActionButtonLabel(
                    title: item.title,
                    systemImageName: item.systemImageName,
                    iconOverride: foreground,
                    textOverride: foreground
                )
            }
            .applySwipeActionTintIfNeeded(item.tint)
            .accessibilityIdentifierIfAvailable(item.accessibilityID)
        }
    }

    // MARK: - Label
    private struct UnifiedSwipeActionButtonLabel: View {
        let title: String
        let systemImageName: String
        let iconOverride: Color?
        let textOverride: Color?

        var body: some View {
            Label {
                Text(title)
                    .foregroundStyle(textOverride ?? .primary)
            } icon: {
                if let iconOverride {
                    Image(systemName: systemImageName)
                        .renderingMode(.template)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconOverride)
                } else {
                    Image(systemName: systemImageName)
                        .foregroundStyle(textOverride ?? .primary)
                }
            }
        }
    }

    // MARK: - Helpers
    private func triggerDelete() {
        #if os(iOS)
        if config.playHapticOnDelete {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        #endif
        onDelete()
    }

}

// MARK: - View Extension
public extension View {
    func unifiedSwipeActions(
        _ config: UnifiedSwipeConfig = .standard,
        onEdit: (() -> Void)? = nil,
        onDelete: @escaping () -> Void,
        customActions: [UnifiedSwipeCustomAction] = []
    ) -> some View {
        modifier(UnifiedSwipeActionsModifier(
            config: config,
            onEdit: onEdit,
            onDelete: onDelete,
            customActions: customActions
        ))
    }
}

// MARK: - Helpers
private extension View {
    @ViewBuilder
    func accessibilityIdentifierIfAvailable(_ identifier: String?) -> some View {
        if let identifier {
            #if os(iOS)
            self.accessibilityIdentifier(identifier)
            #else
            self
            #endif
        } else {
            self
        }
    }

    @ViewBuilder
    func ub_swipeActionTint(_ color: Color) -> some View {
        self.tint(color)
    }

    @ViewBuilder
    func applySwipeActionTintIfNeeded(_ color: Color?) -> some View {
        if let color {
            ub_swipeActionTint(color)
        } else {
            self
        }
    }
}

// MARK: - Color Helpers
private extension Color {
    var ub_contrastingForegroundColor: Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        return Color.contrastingColor(red: r, green: g, blue: b)
        #elseif canImport(AppKit)
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(calibratedWhite: 1.0, alpha: 1.0)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color.contrastingColor(red: r, green: g, blue: b)
        #else
        return .white
        #endif
    }

    static func contrastingColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> Color {
        let brightness = 0.299*red + 0.587*green + 0.114*blue
        return brightness < 0.6 ? .white : .black
    }
}
