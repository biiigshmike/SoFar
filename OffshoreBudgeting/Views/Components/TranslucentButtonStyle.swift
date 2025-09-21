import SwiftUI

/// Button style that mirrors the OS 26 translucent appearance used throughout
/// the onboarding flow. It automatically consults `PlatformCapabilities` so
/// that modern systems render the material treatment while older versions fall
/// back to a subtly tinted material (no gradients).
struct TranslucentButtonStyle: ButtonStyle {
    struct Metrics {
        enum Layout {
            case expandHorizontally
            case hugging
        }

        var layout: Layout = .expandHorizontally
        var width: CGFloat? = nil
        var height: CGFloat? = nil
        var cornerRadius: CGFloat = 26
        var horizontalPadding: CGFloat = DS.Spacing.l
        var verticalPadding: CGFloat = DS.Spacing.m
        var pressedScale: CGFloat = 0.98
        var font: Font? = nil

        static let standard = Metrics()

        static let rootActionIcon = Metrics(
            layout: .hugging,
            width: 44,
            height: 44,
            cornerRadius: 22,
            horizontalPadding: 0,
            verticalPadding: 0,
            pressedScale: 0.94,
            font: .system(size: 18, weight: .semibold)
        )

        static let rootActionLabel = Metrics(
            layout: .hugging,
            width: nil,
            height: 44,
            cornerRadius: 22,
            horizontalPadding: DS.Spacing.l,
            verticalPadding: 0,
            pressedScale: 0.94,
            font: .system(size: 17, weight: .semibold, design: .rounded)
        )
    }

    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    /// Primary tint used for the button background and glow treatments.
    var tint: Color
    var metrics: Metrics

    init(tint: Color, metrics: Metrics = .standard) {
        self.tint = tint
        self.metrics = metrics
    }

    func makeBody(configuration: Configuration) -> some View {
        let radius = metrics.cornerRadius
        let theme = themeManager.selectedTheme

        return configuration.label
            .font(metrics.font ?? .headline)
            .foregroundStyle(labelForeground(for: theme))
            .padding(.vertical, metrics.verticalPadding)
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(maxWidth: metrics.layout == .expandHorizontally ? .infinity : nil)
            .frame(width: metrics.width, height: metrics.height)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(for: theme, isPressed: configuration.isPressed, radius: radius))
            .overlay(border(for: theme, isPressed: configuration.isPressed, radius: radius))
            .overlay(highlight(radius: radius))
            .overlay(glow(for: theme, radius: radius, isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? metrics.pressedScale : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }

    private func labelForeground(for theme: AppTheme) -> Color {
        theme == .system ? Color.primary : Color.white
    }

    @ViewBuilder
    private func background(for theme: AppTheme, isPressed: Bool, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(fillColor(for: theme, isPressed: isPressed)))
                .shadow(
                    color: shadowColor(for: theme, isPressed: isPressed),
                    radius: shadowRadius(isPressed: isPressed),
                    x: 0,
                    y: shadowY(isPressed: isPressed)
                )
                .compositingGroup()
        } else {
            shape
                .fill(fillColor(for: theme, isPressed: isPressed))
                .shadow(
                    color: shadowColor(for: theme, isPressed: isPressed),
                    radius: legacyShadowRadius(isPressed: isPressed),
                    x: 0,
                    y: legacyShadowY(isPressed: isPressed)
                )
        }
    }

    private func fillColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.white.opacity(isPressed ? 0.38 : 0.30)
        } else {
            return tint.opacity(isPressed ? 0.40 : 0.32)
        }
    }

    private func shadowColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.black.opacity(isPressed ? 0.20 : 0.28)
        } else {
            return tint.opacity(isPressed ? 0.32 : 0.42)
        }
    }

    private func shadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 9 : 16
    }

    private func shadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 4 : 10
    }

    private func legacyShadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 7 : 12
    }

    private func legacyShadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 4 : 9
    }

    private func border(for theme: AppTheme, isPressed: Bool, radius: CGFloat) -> some View {
        let lineWidth: CGFloat = capabilities.supportsOS26Translucency ? 1.15 : 1.0

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(borderColor(for: theme, isPressed: isPressed), lineWidth: lineWidth)
    }

    private func highlight(radius: CGFloat) -> some View {
        let whiteOpacity = capabilities.supportsOS26Translucency ? 0.24 : 0.18

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(whiteOpacity), lineWidth: capabilities.supportsOS26Translucency ? 0.9 : 0.8)
            .blendMode(.screen)
    }

    private func glow(for theme: AppTheme, radius: CGFloat, isPressed: Bool) -> some View {
        let glowOpacity = glowOpacity(for: theme, isPressed: isPressed)
        let strokeWidth: CGFloat = capabilities.supportsOS26Translucency ? 12 : 9
        let blurRadius: CGFloat = capabilities.supportsOS26Translucency ? 16 : 12

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(glowColor(for: theme), lineWidth: strokeWidth)
            .blur(radius: blurRadius)
            .opacity(glowOpacity)
            .blendMode(.screen)
    }

    private func glowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white : tint
    }

    private func glowOpacity(for theme: AppTheme, isPressed: Bool) -> Double {
        let base: Double = theme == .system ? 0.32 : 0.42
        return isPressed ? base * 0.6 : base
    }

    private func borderColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.white.opacity(isPressed ? 0.60 : 0.50)
        } else {
            return tint.opacity(isPressed ? 0.70 : 0.58)
        }
    }
}
