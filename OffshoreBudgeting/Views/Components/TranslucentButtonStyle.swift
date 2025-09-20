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
        tint.opacity(isPressed ? 0.32 : 0.24)
    }

    private func shadowColor(isPressed: Bool) -> Color {
        tint.opacity(isPressed ? 0.28 : 0.34)
    }

    private func shadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 12 : 22
    }

    private func shadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 6 : 12
    }

    private func legacyShadowRadius(isPressed: Bool) -> CGFloat {
        isPressed ? 10 : 18
    }

    private func legacyShadowY(isPressed: Bool) -> CGFloat {
        isPressed ? 6 : 12
    }

    private func border(isPressed: Bool, radius: CGFloat) -> some View {
        let opacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.65 : 0.52) : (isPressed ? 0.55 : 0.42)
        let lineWidth: CGFloat = capabilities.supportsOS26Translucency ? 1.2 : 1.0

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(tint.opacity(opacity), lineWidth: lineWidth)
    }

    private func highlight(radius: CGFloat) -> some View {
        let whiteOpacity = capabilities.supportsOS26Translucency ? 0.28 : 0.20

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(whiteOpacity), lineWidth: capabilities.supportsOS26Translucency ? 1.0 : 0.9)
            .blendMode(.screen)
    }
}
