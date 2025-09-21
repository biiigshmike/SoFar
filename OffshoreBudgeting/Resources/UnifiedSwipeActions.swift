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
    public var deleteTint: Color
    public var editTitle: String
    public var editSystemImageName: String
    public var editTint: Color = .accentColor.opacity(0.01)
    public var allowsFullSwipeToDelete: Bool
    public var playHapticOnDelete: Bool
    public var deleteAccessibilityID: String?
    public var editAccessibilityID: String?

    public init(
        showsEditAction: Bool = true,
        deleteTitle: String = "Delete",
        deleteSystemImageName: String = "trash",
        deleteTint: Color = .accentColor,
        editTitle: String = "Edit",
        editSystemImageName: String = "pencil",
        editTint: Color = .accentColor,
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
    @Environment(\.colorScheme) private var environmentColorScheme
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
        Button(role: .destructive) {
            triggerDelete()
        } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.deleteTitle,
                systemImageName: config.deleteSystemImageName,
                tint: config.deleteTint,
                iconOverride: nil,
                colorScheme: effectiveColorScheme
            )
        }
        .enforceDarkGlyph(using: effectiveColorScheme)
        .ub_swipeActionTint(config.deleteTint)
        .accessibilityIdentifierIfAvailable(config.deleteAccessibilityID)
    }

    @ViewBuilder
    private func editButton(onEdit: @escaping () -> Void) -> some View {
        Button { onEdit() } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.editTitle,
                systemImageName: config.editSystemImageName,
                tint: config.editTint,
                iconOverride: nil,
                colorScheme: effectiveColorScheme
            )
        }
        .enforceDarkGlyph(using: effectiveColorScheme)
        .ub_swipeActionTint(config.editTint)
        .accessibilityIdentifierIfAvailable(config.editAccessibilityID)
    }

    @ViewBuilder
    private func customButtons() -> some View {
        ForEach(customActions) { item in
            Button(role: item.role) { item.action() } label: {
                UnifiedSwipeActionButtonLabel(
                    title: item.title,
                    systemImageName: item.systemImageName,
                    tint: item.tint,
                    iconOverride: item.role == .destructive ? item.tint.ub_contrastingForegroundColor : nil,
                    colorScheme: effectiveColorScheme
                )
            }
            .enforceDarkGlyph(using: effectiveColorScheme)
            .ub_swipeActionTint(item.tint)
            .accessibilityIdentifierIfAvailable(item.accessibilityID)
        }
    }

    // MARK: - Label
    private struct UnifiedSwipeActionButtonLabel: View {
        let title: String
        let systemImageName: String
        let tint: Color
        let iconOverride: Color?
        let colorScheme: ColorScheme

        var body: some View {
            if #available(iOS 18.0, macOS 15.0, *) {
                ZStack {
                    Circle().fill(backgroundCircleColor)
                    Image(systemName: systemImageName)
                        .renderingMode(.template)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(resolvedIconColor)
                        .foregroundColor(resolvedIconColor)
                }
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title))
            } else {
                Label { Text(title) } icon: {
                    Image(systemName: systemImageName)
                        .renderingMode(.template)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(resolvedIconColor)
                        .foregroundColor(resolvedIconColor)
                }
                .foregroundColor(resolvedIconColor)
            }
        }

        private var resolvedIconColor: Color {
            if let override = iconOverride { return override }
            if colorScheme == .dark { return .black }       // minimal rule: always black in dark mode
            return tint.ub_contrastingForegroundColor
        }

        private var backgroundCircleColor: Color {
            if #available(iOS 18.0, macOS 15.0, *) {
                return colorScheme == .dark ? .white
                                            : resolvedTint(opacity: 0.65)
            }
            #if canImport(UIKit) || canImport(AppKit)
            if let c = tint.ub_resolvedRGBA(for: colorScheme) {
                if colorScheme == .dark {
                    let blend: CGFloat = 0.35
                    return Color(red: Double(c.red*(1-blend)),
                                green: Double(c.green*(1-blend)),
                                blue: Double(c.blue*(1-blend)),
                                opacity: Double(c.alpha)).opacity(0.55)
                } else {
                    return Color(red: Double(c.red), green: Double(c.green), blue: Double(c.blue), opacity: Double(c.alpha)).opacity(0.25)
                }
            }
            #endif
            return tint.opacity(colorScheme == .dark ? 0.35 : 0.25)
        }

        private func resolvedTint(opacity: Double) -> Color {
            #if canImport(UIKit) || canImport(AppKit)
            if let c = tint.ub_resolvedRGBA(for: colorScheme) {
                return Color(red: Double(c.red), green: Double(c.green), blue: Double(c.blue), opacity: Double(c.alpha)).opacity(opacity)
            }
            #endif
            return tint.opacity(opacity)
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

    private var effectiveColorScheme: ColorScheme {
        #if os(macOS)
        let application = NSApp ?? NSApplication.shared
        let match = application.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        if match == .darkAqua { return .dark }
        if match == .aqua { return .light }
        #endif
        return environmentColorScheme
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

    // Ensure black glyphs in Dark Mode regardless of system styling
    @ViewBuilder
    func enforceDarkGlyph(using colorScheme: ColorScheme) -> some View {
        self.modifier(ForceDarkGlyphModifier(colorScheme: colorScheme))
    }

    @ViewBuilder
    func ub_swipeActionTint(_ color: Color) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) { self } else { self.tint(color) }
        #elseif os(macOS)
        if #available(macOS 15.0, *) { self } else { self.tint(color) }
        #else
        self.tint(color)
        #endif
    }
}

private struct ForceDarkGlyphModifier: ViewModifier {
    let colorScheme: ColorScheme
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            #if os(iOS)
            if #available(iOS 18.0, *) {
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
            } else {
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
            } else {
                content
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
            }
            #else
            content
                .buttonStyle(.plain)
                .foregroundStyle(.black)
            #endif
        } else {
            content
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

    func ub_resolvedRGBA(for colorScheme: ColorScheme) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        let trait = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let resolved = ui.resolvedColor(with: trait)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
        #elseif canImport(AppKit)
        let ns = NSColor(self)
        let converted = ns.usingColorSpace(.sRGB) ?? ns
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        return nil
        #endif
    }

    static func contrastingColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> Color {
        let brightness = 0.299*red + 0.587*green + 0.114*blue
        return brightness < 0.6 ? .white : .black
    }
}
