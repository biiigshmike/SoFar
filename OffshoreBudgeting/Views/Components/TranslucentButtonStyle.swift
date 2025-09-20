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
            .foregroundStyle(Color.white)
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(isPressed: configuration.isPressed, radius: radius))
            .overlay(highlight(radius: radius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            let whiteOverlayOpacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.20 : 0.26) : (isPressed ? 0.18 : 0.22)
            let tintOverlayOpacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.30 : 0.36) : (isPressed ? 0.24 : 0.30)
            let tintShadowOpacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.18 : 0.26) : (isPressed ? 0.16 : 0.22)
            let whiteShadowOpacity = capabilities.supportsOS26Translucency ? (isPressed ? 0.24 : 0.40) : (isPressed ? 0.18 : 0.30)

            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .fill(Color.white.opacity(whiteOverlayOpacity))
                        .blendMode(.plusLighter)
                )
                .overlay(
                    shape
                        .fill(tint.opacity(tintOverlayOpacity))
                        .blendMode(.plusLighter)
                )
                .shadow(
                    color: tint.opacity(tintShadowOpacity),
                    radius: isPressed ? 12 : 22,
                    x: 0,
                    y: isPressed ? 6 : 12
                )
                .shadow(
                    color: Color.white.opacity(whiteShadowOpacity),
                    radius: isPressed ? 3 : 9,
                    x: 0,
                    y: isPressed ? 1 : 4
                )
                .compositingGroup()
        } else {
            shape
                .fill(tint.opacity(isPressed ? 0.32 : 0.38))
                .shadow(color: tint.opacity(isPressed ? 0.16 : 0.22), radius: isPressed ? 10 : 18, x: 0, y: isPressed ? 6 : 12)
                .shadow(color: Color.black.opacity(isPressed ? 0.04 : 0.08), radius: isPressed ? 6 : 12, x: 0, y: isPressed ? 2 : 6)
        }
    }

    @ViewBuilder
    private func highlight(radius: CGFloat) -> some View {
        let whiteOpacity = capabilities.supportsOS26Translucency ? 0.42 : 0.28
        let tintOpacity = capabilities.supportsOS26Translucency ? 0.24 : 0.18

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(whiteOpacity), lineWidth: capabilities.supportsOS26Translucency ? 1.2 : 1)
            .blendMode(.screen)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(tintOpacity), lineWidth: 0.9)
                    .blendMode(.plusLighter)
            )
    }
}
