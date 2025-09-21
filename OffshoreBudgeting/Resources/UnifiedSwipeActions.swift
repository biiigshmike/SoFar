//
//  UnifiedSwipeActions.swift
//  SoFar
//
//  Created by You, with love and consistency.
//  Cross-platform: iOS, iPadOS, macOS
//

import SwiftUI
#if os(iOS)
// MARK: - iOS-only import for haptics
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - UnifiedSwipeConfig
/// Describes the look and behavior of the standardized swipe actions.
/// You can tweak titles, icons, tints, and whether a full swipe should auto-trigger Delete (Apple Mail style).
public struct UnifiedSwipeConfig {
    // MARK: Properties
    /// Show an Edit action alongside Delete; only shown if you also provide an `onEdit` closure.
    public var showsEditAction: Bool

    /// Title for the Delete button; localized string is fine.
    public var deleteTitle: String

    /// SF Symbol used for Delete.
    public var deleteSystemImageName: String

    /// Tint color used for Delete in non-destructive contexts; role still sets the red style on iOS automatically.
    public var deleteTint: Color

    /// Title for the Edit button.
    public var editTitle: String

    /// SF Symbol used for Edit.
    public var editSystemImageName: String

    /// Tint color used for Edit.
    public var editTint: Color = .accentColor.opacity(0.01)

    /// When supported, a full swipe should trigger the first destructive action automatically; set to `true` for Mail-like behavior.
    public var allowsFullSwipeToDelete: Bool

    /// Whether to play a subtle haptic on delete (iOS only).
    public var playHapticOnDelete: Bool

    /// Optional accessibility identifiers for UI tests.
    public var deleteAccessibilityID: String?
    public var editAccessibilityID: String?

    // MARK: Init
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

    // MARK: Presets
    /// Standard config used across the app; Mail-style full swipe to delete.
    public static let standard = UnifiedSwipeConfig()

    /// A config that hides Edit; useful for rows that do not support editing.
    public static let deleteOnly = UnifiedSwipeConfig(showsEditAction: false)
}

// MARK: - UnifiedSwipeCustomAction
/// Represents an extra custom action you may want in addition to Edit/Delete.
/// Example: "Flag", "Duplicate", etc.
public struct UnifiedSwipeCustomAction: Identifiable {
    // MARK: Properties
    public let id = UUID()
    public var title: String
    public var systemImageName: String
    public var tint: Color
    public var role: ButtonRole?
    public var accessibilityID: String?
    public var action: () -> Void

    // MARK: Init
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
/// ViewModifier that applies the unified swipe actions to any row-like view.
/// It uses native `.swipeActions` where available; falls back to `.contextMenu` on older macOS.
private struct UnifiedSwipeActionsModifier: ViewModifier {

    // MARK: Properties
    let config: UnifiedSwipeConfig
    let onEdit: (() -> Void)?
    let onDelete: () -> Void
    let customActions: [UnifiedSwipeCustomAction]

    // MARK: Body
    func body(content: Content) -> some View {
        // We always attach a context menu for parity; the native swipe is added where available.
        let base = content.contextMenu {
            if let onEdit, config.showsEditAction {
                Button {
                    onEdit()
                } label: {
                    Label(config.editTitle, systemImage: config.editSystemImageName)
                }
                .help(config.editTitle)
                .accessibilityIdentifierIfAvailable(config.editAccessibilityID)
            }

            ForEach(customActions) { item in
                Button(role: item.role) {
                    item.action()
                } label: {
                    Label(item.title, systemImage: item.systemImageName)
                }
                .tint(item.tint)
                .help(item.title)
                .accessibilityIdentifierIfAvailable(item.accessibilityID)
            }

            Divider()

            Button(role: .destructive) {
                triggerDelete()
            } label: {
                Label(config.deleteTitle, systemImage: config.deleteSystemImageName)
            }
            .help(config.deleteTitle)
            .accessibilityIdentifierIfAvailable(config.deleteAccessibilityID)
        }

        // Attach native swipe actions where supported.
        #if os(iOS)
        if #available(iOS 15.0, *) {
            base
                .swipeActions(edge: .trailing, allowsFullSwipe: config.allowsFullSwipeToDelete) {
                    // The first destructive button becomes the "full swipe" commit; put Delete first.
                    deleteButton()
                    // A slower reveal shows the remaining actions; mirrors the Mail behavior.
                    if let onEdit, config.showsEditAction {
                        editButton(onEdit: onEdit)
                    }
                    customButtons()
                }
        } else {
            base
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            base
                // macOS does not support allowsFullSwipe; this still reveals actions with a two-finger swipe.
                .swipeActions(edge: .trailing) {
                    deleteButton()
                    if let onEdit, config.showsEditAction {
                        editButton(onEdit: onEdit)
                    }
                    customButtons()
                }
        } else {
            base
        }
        #else
        // tvOS/watchOS not targeted; keep the context menu only.
        base
        #endif
    }

    // MARK: - Button Builders
    /// Builds the Delete button; first in order to be the full-swipe action on platforms that support it.
    @ViewBuilder
    private func deleteButton() -> some View {
        Button(role: .destructive) {
            triggerDelete()
        } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.deleteTitle,
                systemImageName: config.deleteSystemImageName,
                tint: config.deleteTint
            )
        }
        .ub_swipeActionTint(config.deleteTint)
        .accessibilityIdentifierIfAvailable(config.deleteAccessibilityID)
    }

    /// Builds the Edit button.
    @ViewBuilder
    private func editButton(onEdit: @escaping () -> Void) -> some View {
        Button {
            onEdit()
        } label: {
            UnifiedSwipeActionButtonLabel(
                title: config.editTitle,
                systemImageName: config.editSystemImageName,
                tint: config.editTint
            )
        }
        .ub_swipeActionTint(config.editTint)
        .accessibilityIdentifierIfAvailable(config.editAccessibilityID)
    }

    /// Builds any custom buttons provided by the caller.
    @ViewBuilder
    private func customButtons() -> some View {
        ForEach(customActions) { item in
            Button(role: item.role) {
                item.action()
            } label: {
                UnifiedSwipeActionButtonLabel(
                    title: item.title,
                    systemImageName: item.systemImageName,
                    tint: item.tint,
                    iconOverride: item.role == .destructive ? item.tint.ub_contrastingForegroundColor : nil
                )
            }
            .ub_swipeActionTint(item.tint)
            .accessibilityIdentifierIfAvailable(item.accessibilityID)
        }
    }

    // MARK: - UnifiedSwipeActionButtonLabel
    /// Produces a label that adapts to the new OS 26 circular swipe buttons while
    /// maintaining the legacy label appearance on older releases.
    private struct UnifiedSwipeActionButtonLabel: View {
        @Environment(\.colorScheme) private var colorScheme
        let title: String
        let systemImageName: String
        let tint: Color
        let iconOverride: Color?

        init(
            title: String,
            systemImageName: String,
            tint: Color,
            iconOverride: Color? = nil
        ) {
            self.title = title
            self.systemImageName = systemImageName
            self.tint = tint
            self.iconOverride = iconOverride
        }

        var body: some View {
            if #available(iOS 18.0, macOS 15.0, *) {
                ZStack {
                    Circle()
                        .fill(backgroundCircleColor)

                    Image(systemName: systemImageName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 44, height: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title))
            } else {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImageName)
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconColor)
                }
                .foregroundColor(iconColor)
            }
        }

        private var iconColor: Color {
            iconOverride ?? tint.ub_contrastingForegroundColor(for: colorScheme)
        }

        private var backgroundCircleColor: Color {
            if #available(iOS 18.0, macOS 15.0, *) {
                return resolvedTint(opacity: colorScheme == .dark ? 0.85 : 0.65)
            }
            #if canImport(UIKit) || canImport(AppKit)
            if let components = tint.ub_resolvedRGBA(for: colorScheme) {
                if colorScheme == .dark {
                    let blend: CGFloat = 0.35
                    let red = components.red * (1 - blend)
                    let green = components.green * (1 - blend)
                    let blue = components.blue * (1 - blend)
                    return Color(
                        red: Double(red),
                        green: Double(green),
                        blue: Double(blue),
                        opacity: Double(components.alpha)
                    ).opacity(0.55)
                } else {
                    return Color(
                        red: Double(components.red),
                        green: Double(components.green),
                        blue: Double(components.blue),
                        opacity: Double(components.alpha)
                    ).opacity(0.25)
                }
            }
            #endif

            return tint.opacity(colorScheme == .dark ? 0.35 : 0.25)
        }

        private func resolvedTint(opacity: Double) -> Color {
            #if canImport(UIKit) || canImport(AppKit)
            if let components = tint.ub_resolvedRGBA(for: colorScheme) {
                return Color(
                    red: Double(components.red),
                    green: Double(components.green),
                    blue: Double(components.blue),
                    opacity: Double(components.alpha)
                ).opacity(opacity)
            }
            #endif
            return tint.opacity(opacity)
        }
    }

    // MARK: - Helpers
    /// Wraps delete action with an optional haptic for iOS; then calls the user-provided delete closure.
    private func triggerDelete() {
        #if os(iOS)
        if config.playHapticOnDelete {
            // Light impact; keeps it classy.
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        #endif
        onDelete()
    }
}

// MARK: - View Extension
public extension View {

    // MARK: unifiedSwipeActions(config:onEdit:onDelete:customActions:)
    /// Applies unified, consistent swipe actions to any row view.
    ///
    /// - Parameters:
    ///   - config: A `UnifiedSwipeConfig` to control titles, icons, tints, and full-swipe behavior; defaults to `.standard`.
    ///   - onEdit: Optional closure invoked when the user taps Edit; if `nil` or `config.showsEditAction` is `false`, Edit is omitted.
    ///   - onDelete: Closure invoked when the user taps Delete or performs a full swipe where supported.
    ///   - customActions: Optional array of `UnifiedSwipeCustomAction` to add more actions; they appear after Edit.
    ///
    /// - Usage:
    ///   ```swift
    ///   row.unifiedSwipeActions(
    ///       onEdit: { viewModel.beginEditing(rowID) },
    ///       onDelete: { viewModel.delete(rowID) }
    ///   )
    ///   ```
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

// MARK: - Accessibility Identifier Helper
private extension View {
    /// Adds an accessibility identifier where supported; no-op where unavailable.
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

    /// Applies a tint color for swipe actions, skipping newer OS releases where
    /// the system draws circular backgrounds for us and we render the tint
    /// manually inside the button label.
    @ViewBuilder
    func ub_swipeActionTint(_ color: Color) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self
        } else {
            self.tint(color)
        }
        #elseif os(macOS)
        if #available(macOS 15.0, *) {
            self
        } else {
            self.tint(color)
        }
        #else
        self.tint(color)
        #endif
    }
}

// MARK: - Color Helpers
private extension Color {
    /// Returns either black or white depending on which provides the best
    /// contrast for the supplied color. Used to ensure OS 26 style swipe
    /// buttons remain legible regardless of tint.
    var ub_contrastingForegroundColor: Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }
        return Color.contrastingColor(red: red, green: green, blue: blue)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(calibratedWhite: 1.0, alpha: 1.0)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color.contrastingColor(red: red, green: green, blue: blue)
        #else
        return .white
        #endif
    }

    /// Returns a contrasting foreground color that respects the provided
    /// color scheme when resolving dynamic colors.
    func ub_contrastingForegroundColor(for colorScheme: ColorScheme) -> Color {
        #if canImport(UIKit) || canImport(AppKit)
        if let components = ub_resolvedRGBA(for: colorScheme) {
            return Color.contrastingColor(
                red: components.red,
                green: components.green,
                blue: components.blue
            )
        }
        #endif
        return ub_contrastingForegroundColor
    }

    /// Resolves the color for the provided color scheme and exposes RGBA
    /// components for additional calculations.
    func ub_resolvedRGBA(for colorScheme: ColorScheme) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        let trait = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let resolved = uiColor.resolvedColor(with: trait)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (red, green, blue, alpha)
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.sRGB) ?? NSColor(calibratedWhite: 1.0, alpha: 1.0)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
        #else
        return nil
        #endif
    }

    static func contrastingColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> Color {
        let brightness = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return brightness < 0.6 ? .white : .black
    }
}
