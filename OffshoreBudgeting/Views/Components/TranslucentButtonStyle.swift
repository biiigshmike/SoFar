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
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(isPressed ? 0.32 : 0.4))
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .shadow(
                    color: tint.opacity(isPressed ? 0.26 : 0.38),
                    radius: isPressed ? 14 : 24,
                    x: 0,
                    y: isPressed ? 10 : 16
                )
                .compositingGroup()
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.95),
                            tint.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(0.28), radius: 12, x: 0, y: 8)
        }
    }

    @ViewBuilder
    private func highlight(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(capabilities.supportsOS26Translucency ? 0.28 : 0.18), lineWidth: 1)
            .blendMode(.screen)
    }
}
