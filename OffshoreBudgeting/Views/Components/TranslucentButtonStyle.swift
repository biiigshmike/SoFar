import SwiftUI

/// Button style that mirrors the OS 26 translucent appearance used throughout
/// the onboarding flow. It automatically consults `PlatformCapabilities` so
/// that modern systems render the material treatment while older versions fall
/// back to a softly tinted fill.
struct TranslucentButtonStyle: ButtonStyle {
    @Environment(\.platformCapabilities) private var capabilities

    /// Primary tint used for the button background and glow treatments.
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = 26

        return configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(isPressed: configuration.isPressed, radius: radius))
            .overlay(highlight(isPressed: configuration.isPressed, radius: radius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if capabilities.supportsOS26Translucency, #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(glassWhiteOverlayOpacity(isPressed: isPressed)).blendMode(.plusLighter))
                .overlay(shape.fill(glassTintOverlayOpacity(isPressed: isPressed)).blendMode(.plusLighter))
                .overlay(shape.stroke(glassBorderOpacity(isPressed: isPressed), lineWidth: 1.05))
                .shadow(color: tint.opacity(isPressed ? 0.16 : 0.24), radius: isPressed ? 11 : 20, x: 0, y: isPressed ? 6 : 12)
                .shadow(color: Color.black.opacity(isPressed ? 0.04 : 0.08), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                .compositingGroup()
        } else {
            shape
                .fill(legacyFillColor(isPressed: isPressed))
                .overlay(shape.stroke(legacyBorderColor(isPressed: isPressed), lineWidth: 1))
                .shadow(color: tint.opacity(isPressed ? 0.16 : 0.22), radius: isPressed ? 9 : 16, x: 0, y: isPressed ? 5 : 11)
                .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.09), radius: isPressed ? 5 : 9, x: 0, y: isPressed ? 2 : 5)
        }
    }

    @ViewBuilder
    private func highlight(isPressed: Bool, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(glassHighlightWhiteOpacity(isPressed: isPressed), lineWidth: capabilities.supportsOS26Translucency ? 1.15 : 1)
            .blendMode(.screen)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(glassHighlightTintOpacity(isPressed: isPressed), lineWidth: 0.9)
                    .blendMode(.plusLighter)
            )
    }

    private func glassWhiteOverlayOpacity(isPressed: Bool) -> Color {
        Color.white.opacity(isPressed ? 0.18 : 0.26)
    }

    private func glassTintOverlayOpacity(isPressed: Bool) -> Color {
        tint.opacity(isPressed ? 0.22 : 0.30)
    }

    private func glassBorderOpacity(isPressed: Bool) -> Color {
        Color.white.opacity(isPressed ? 0.26 : 0.32)
    }

    private func glassHighlightWhiteOpacity(isPressed: Bool) -> Color {
        Color.white.opacity(capabilities.supportsOS26Translucency ? (isPressed ? 0.42 : 0.48) : (isPressed ? 0.28 : 0.32))
    }

    private func glassHighlightTintOpacity(isPressed: Bool) -> Color {
        tint.opacity(capabilities.supportsOS26Translucency ? (isPressed ? 0.18 : 0.24) : (isPressed ? 0.12 : 0.18))
    }

    private func legacyFillColor(isPressed: Bool) -> Color {
        tint.opacity(isPressed ? 0.58 : 0.62)
    }

    private func legacyBorderColor(isPressed: Bool) -> Color {
        Color.white.opacity(isPressed ? 0.32 : 0.36)
    }
}
