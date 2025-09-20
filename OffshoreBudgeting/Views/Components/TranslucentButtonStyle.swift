import SwiftUI

/// Button style that mirrors the OS 26 translucent appearance used throughout
/// the onboarding flow. It automatically consults `PlatformCapabilities` so
/// that modern systems render the material treatment while older versions fall
/// back to a subtly tinted material (no gradients).
struct TranslucentButtonStyle: ButtonStyle {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    /// Primary tint used for the button background and glow treatments.
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = 26
        let theme = themeManager.selectedTheme

        return configuration.label
            .font(.headline)
            .foregroundStyle(labelForeground(for: theme))
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(for: theme, isPressed: configuration.isPressed, radius: radius))
            .overlay(border(for: theme, isPressed: configuration.isPressed, radius: radius))
            .overlay(highlight(radius: radius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
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
            return Color.white.opacity(isPressed ? 0.26 : 0.20)
        } else {
            return tint.opacity(isPressed ? 0.32 : 0.24)
        }
    }

    private func shadowColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.black.opacity(isPressed ? 0.18 : 0.24)
        } else {
            return tint.opacity(isPressed ? 0.22 : 0.30)
        }
    }

    private func shadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 6 : 10
    }

    private func shadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 3 : 7
    }

    private func legacyShadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 5 : 9
    }

    private func legacyShadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 3 : 6
    }

    private func border(for theme: AppTheme, isPressed: Bool, radius: CGFloat) -> some View {
        let lineWidth: CGFloat = capabilities.supportsOS26Translucency ? 1.05 : 0.95

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(borderColor(for: theme, isPressed: isPressed), lineWidth: lineWidth)
    }

    private func highlight(radius: CGFloat) -> some View {
        let whiteOpacity = capabilities.supportsOS26Translucency ? 0.20 : 0.16

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(whiteOpacity), lineWidth: capabilities.supportsOS26Translucency ? 0.8 : 0.75)
            .blendMode(.screen)
    }

    private func borderColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.white.opacity(isPressed ? 0.55 : 0.44)
        } else {
            return tint.opacity(isPressed ? 0.66 : 0.54)
        }
    }
}
