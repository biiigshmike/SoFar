import SwiftUI

/// Button style that mirrors the OS 26 translucent appearance used throughout
/// the onboarding flow. It automatically consults `PlatformCapabilities` so
/// that modern systems render the material treatment while older versions fall
/// back to a vibrant gradient.
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
        if capabilities.supportsOS26Translucency, #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            let fill = LinearGradient(
                colors: [
                    Color.white.opacity(isPressed ? 0.18 : 0.26),
                    tint.opacity(isPressed ? 0.24 : 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fill)
                        .blendMode(.plusLighter)
                )
                .shadow(
                    color: tint.opacity(isPressed ? 0.18 : 0.26),
                    radius: isPressed ? 12 : 22,
                    x: 0,
                    y: isPressed ? 6 : 12
                )
                .shadow(
                    color: Color.white.opacity(isPressed ? 0.32 : 0.48),
                    radius: isPressed ? 3 : 9,
                    x: 0,
                    y: isPressed ? 1 : 4
                )
                .compositingGroup()
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            tint.opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(isPressed ? 0.18 : 0.24), radius: isPressed ? 10 : 18, x: 0, y: isPressed ? 6 : 12)
                .shadow(color: Color.black.opacity(isPressed ? 0.06 : 0.1), radius: isPressed ? 6 : 12, x: 0, y: isPressed ? 2 : 6)
        }
    }

    @ViewBuilder
    private func highlight(radius: CGFloat) -> some View {
        let whiteTopOpacity = capabilities.supportsOS26Translucency ? 0.58 : 0.32
        let whiteBottomOpacity = capabilities.supportsOS26Translucency ? 0.12 : 0.08

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(whiteTopOpacity),
                        Color.white.opacity(whiteBottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: capabilities.supportsOS26Translucency ? 1.2 : 1
            )
            .blendMode(.screen)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tint.opacity(capabilities.supportsOS26Translucency ? 0.24 : 0.18),
                                tint.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                    .blendMode(.plusLighter)
            )
    }
}
