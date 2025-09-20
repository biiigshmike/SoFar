import SwiftUI

/// Button style that mirrors the OS 26 translucent appearance used throughout
/// the onboarding flow. It automatically consults `PlatformCapabilities` so
/// that modern systems render the material treatment while older versions fall
/// back to a subtly tinted material (no gradients).
struct TranslucentButtonStyle: ButtonStyle {
    @Environment(\.platformCapabilities) private var capabilities

    /// Primary tint used for the button background and glow treatments.
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = 26

        return configuration.label
            .font(.headline)
            .foregroundStyle(labelForeground)
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(isPressed: configuration.isPressed, radius: radius))
            .overlay(border(isPressed: configuration.isPressed, radius: radius))
            .overlay(highlight(radius: radius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }

    private var labelForeground: Color {
        Color.white
    }

    @ViewBuilder
    private func background(isPressed: Bool, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(fillColor(isPressed: isPressed)))
                .shadow(color: shadowColor(isPressed: isPressed), radius: shadowRadius(isPressed: isPressed), x: 0, y: shadowY(isPressed: isPressed))
                .compositingGroup()
        } else {
            shape
                .fill(fillColor(isPressed: isPressed))
                .shadow(color: shadowColor(isPressed: isPressed), radius: legacyShadowRadius(isPressed: isPressed), x: 0, y: legacyShadowY(isPressed: isPressed))
        }
    }

    private func fillColor(isPressed: Bool) -> Color {
        Color.white.opacity(isPressed ? 0.22 : 0.18)
    }

    private func shadowColor(isPressed: Bool) -> Color {
        Color.black.opacity(isPressed ? 0.10 : 0.14)
    }

    private func shadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 5 : 9
    }

    private func shadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 2 : 5
    }

    private func legacyShadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 4 : 8
    }

    private func legacyShadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 2 : 5
    }

    private func border(isPressed: Bool, radius: CGFloat) -> some View {
        let opacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.48 : 0.36) : (isPressed ? 0.40 : 0.30)
        let lineWidth: CGFloat = capabilities.supportsOS26Translucency ? 0.9 : 0.8

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(tint.opacity(opacity), lineWidth: lineWidth)
    }

    private func highlight(radius: CGFloat) -> some View {
        let whiteOpacity = capabilities.supportsOS26Translucency ? 0.20 : 0.16

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(whiteOpacity), lineWidth: capabilities.supportsOS26Translucency ? 0.8 : 0.75)
            .blendMode(.screen)
    }
}
