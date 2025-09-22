import SwiftUI

// MARK: - Shared Metrics
enum RootHeaderActionMetrics {
    static let dimension: CGFloat = 44
}

enum RootHeaderGlassMetrics {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 6
}

// MARK: - Icon Content
struct RootHeaderControlIcon: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(foregroundColor)
    }

    private var foregroundColor: Color {
        themeManager.selectedTheme == .system ? Color.primary : Color.white
    }
}

// MARK: - Action Button Style
struct RootHeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Optional Accessibility Identifier
#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
#else
private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View { content }
}
#endif

extension View {
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(OptionalAccessibilityIdentifierModifier(identifier: identifier))
    }
}

// MARK: - Header Glass Controls (iOS + macOS)
#if os(iOS) || os(macOS)

#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
@available(iOS 18.0, macOS 15.0, tvOS 18.0, macCatalyst 18.0, *)
private struct RootHeaderGlassCapsuleContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer {
            content
                .glassEffect(in: Capsule(style: .continuous))
        }
    }
}
#endif

private extension View {
    @ViewBuilder
    func rootHeaderGlassDecorated(
        theme: AppTheme,
        capabilities: PlatformCapabilities
    ) -> some View {
#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
        if capabilities.supportsOS26Translucency {
            if #available(iOS 18.0, macOS 15.0, tvOS 18.0, macCatalyst 18.0, *) {
                RootHeaderGlassCapsuleContainer { self }
            } else {
                rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
            }
        } else {
            rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
        }
#else
        rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
#endif
    }
}

struct RootHeaderGlassPill<Leading: View, Trailing: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let leading: Leading
    private let trailing: Trailing
    private let showsDivider: Bool
    private let hasTrailing: Bool

    init(
        showsDivider: Bool = true,
        hasTrailing: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
        self.showsDivider = showsDivider
        self.hasTrailing = hasTrailing
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension
        let horizontalPadding = RootHeaderGlassMetrics.horizontalPadding
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding
        let theme = themeManager.selectedTheme

        let content = HStack(spacing: 0) {
            leading
                .frame(width: dimension, height: dimension)
                .contentShape(Rectangle())
                .padding(.leading, horizontalPadding)
                .padding(.trailing, horizontalPadding)
                .padding(.vertical, verticalPadding)

            if showsDivider {
                Rectangle()
                    .fill(RootHeaderLegacyGlass.dividerColor(for: theme))
                    .frame(width: 1, height: dimension)
                    .padding(.vertical, verticalPadding)
            }

            if hasTrailing {
                trailing
                    .frame(minWidth: dimension,
                           idealWidth: dimension,
                           maxHeight: dimension,
                           alignment: .center)
                    .contentShape(Rectangle())
                    .padding(.leading, horizontalPadding)
                    .padding(.trailing, horizontalPadding)
                    .padding(.vertical, verticalPadding)
            }
        }
        .contentShape(Capsule(style: .continuous))

        content
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
    }
}

struct RootHeaderGlassControl<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension
        let theme = themeManager.selectedTheme

        let control = content
            .frame(width: dimension, height: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
            .contentShape(Capsule(style: .continuous))

        control
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
    }
}

enum RootHeaderLegacyGlass {
    static func fillColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.30) : theme.resolvedTint.opacity(0.32)
    }

    static func shadowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.black.opacity(0.28) : theme.resolvedTint.opacity(0.42)
    }

    static func borderColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.50) : theme.resolvedTint.opacity(0.58)
    }

    static func dividerColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.50) : theme.resolvedTint.opacity(0.55)
    }

    static func glowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white : theme.resolvedTint
    }

    static func glowOpacity(for theme: AppTheme) -> Double {
        theme == .system ? 0.32 : 0.42
    }

    static func borderLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 1.15 : 1.0
    }

    static func highlightLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 0.9 : 0.8
    }

    static func highlightOpacity(for capabilities: PlatformCapabilities) -> Double {
        capabilities.supportsOS26Translucency ? 0.24 : 0.18
    }

    static func glowLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 12 : 9
    }

    static func glowBlurRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowYOffset(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 10 : 9
    }
}

extension View {
    func rootHeaderLegacyGlassDecorated(theme: AppTheme, capabilities: PlatformCapabilities) -> some View {
        let shape = Capsule(style: .continuous)
        return self
            .background(
                shape
                    .fill(RootHeaderLegacyGlass.fillColor(for: theme))
                    .shadow(
                        color: RootHeaderLegacyGlass.shadowColor(for: theme),
                        radius: RootHeaderLegacyGlass.shadowRadius(for: capabilities),
                        x: 0,
                        y: RootHeaderLegacyGlass.shadowYOffset(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.borderColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.borderLineWidth(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        Color.white.opacity(RootHeaderLegacyGlass.highlightOpacity(for: capabilities)),
                        lineWidth: RootHeaderLegacyGlass.highlightLineWidth(for: capabilities)
                    )
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.glowColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.glowLineWidth(for: capabilities)
                    )
                    .blur(radius: RootHeaderLegacyGlass.glowBlurRadius(for: capabilities))
                    .opacity(RootHeaderLegacyGlass.glowOpacity(for: theme))
                    .blendMode(.screen)
            )
            .compositingGroup()
    }
}
#endif

// MARK: - Convenience Icon Button
struct RootHeaderIconActionButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var accessibilityIdentifier: String?
    var action: () -> Void
#if os(macOS)
    @Environment(\.platformCapabilities) private var capabilities
#endif

    init(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        #if os(iOS)
        RootHeaderGlassControl {
            baseButton
                .buttonStyle(RootHeaderActionButtonStyle())
        }
        #else
        let fallback = RootHeaderGlassControl {
            baseButton
                .buttonStyle(RootHeaderActionButtonStyle())
        }

        if capabilities.supportsOS26Translucency {
            if #available(macOS 15.0, *) {
                makeMacGlassButton(
                    baseButton: baseButton,
                    dimension: RootHeaderActionMetrics.dimension,
                    horizontalPadding: RootHeaderGlassMetrics.horizontalPadding,
                    verticalPadding: RootHeaderGlassMetrics.verticalPadding
                )
            } else {
                fallback
            }
        } else {
            fallback
        }
        #endif
    }

    private var baseButton: some View {
        Button(action: action) {
            RootHeaderControlIcon(systemImage: systemImage)
        }
        .accessibilityLabel(accessibilityLabel)
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }

#if os(macOS)
    @available(macOS 15.0, *)
    private func makeMacGlassButton<Content: View>(
        baseButton: Content,
        dimension: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        baseButton
            .frame(width: dimension, height: dimension)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Circle())
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
    }
#endif
}
