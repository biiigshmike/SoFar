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
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.32 : 0.45),
                                    tint.opacity(isPressed ? 0.42 : 0.58)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                )
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.18 : 0.24),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: isPressed ? 18 : 22)
                        .offset(y: isPressed ? 6 : 10)
                        .allowsHitTesting(false)
                )
                .shadow(
                    color: Color.white.opacity(isPressed ? 0.22 : 0.34),
                    radius: isPressed ? 8 : 14,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
                .shadow(
                    color: tint.opacity(isPressed ? 0.16 : 0.26),
                    radius: isPressed ? 18 : 28,
                    x: 0,
                    y: isPressed ? 8 : 16
                )
                .shadow(
                    color: Color.black.opacity(isPressed ? 0.04 : 0.06),
                    radius: isPressed ? 4 : 6,
                    x: 0,
                    y: isPressed ? 1 : 3
                )
                .compositingGroup()
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isPressed ? 0.28 : 0.4),
                            tint.opacity(isPressed ? 0.6 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(isPressed ? 0.2 : 0.28), radius: isPressed ? 10 : 18, x: 0, y: isPressed ? 6 : 12)
                .shadow(color: Color.white.opacity(isPressed ? 0.16 : 0.24), radius: isPressed ? 4 : 6, x: 0, y: isPressed ? 1 : 2)
        }
    }

    @ViewBuilder
    private func highlight(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        shape
            .inset(by: 0.5)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(capabilities.supportsOS26Translucency ? 0.65 : 0.32),
                        Color.white.opacity(capabilities.supportsOS26Translucency ? 0.18 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: capabilities.supportsOS26Translucency ? 1.1 : 1
            )
            .blendMode(.screen)
            .overlay(
                shape
                    .stroke(Color.white.opacity(capabilities.supportsOS26Translucency ? 0.22 : 0.14), lineWidth: 0.6)
                    .blur(radius: 1.2)
                    .blendMode(.screen)
                    .mask(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}
