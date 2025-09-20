import SwiftUI

/// Button style that renders compact circular/squircle controls for the income calendar
/// navigation row. The style mirrors the OS 26 translucent appearance while falling back
/// to a subtly tinted material treatment on older systems.
struct CalendarNavigationButtonStyle: ButtonStyle {
    enum Role {
        case icon
        case label
    }

    var role: Role

    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        let height: CGFloat = 34
        let radius: CGFloat = height / 2
        let theme = themeManager.selectedTheme

        return configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor(for: theme))
            .padding(.horizontal, role == .label ? DS.Spacing.m : 0)
            .frame(width: role == .icon ? height : nil, height: height)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(for: theme, radius: radius, isPressed: configuration.isPressed))
            .overlay(border(for: theme, radius: radius, isPressed: configuration.isPressed))
            .overlay(highlight(radius: radius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: configuration.isPressed)
    }

    // MARK: - Layers
    @ViewBuilder
    private func background(for theme: AppTheme, radius: CGFloat, isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .fill(fillColor(for: theme, isPressed: isPressed))
                        .blendMode(.plusLighter)
                )
                .shadow(
                    color: shadowColor(for: theme, isPressed: isPressed),
                    radius: isPressed ? 8 : 12,
                    x: 0,
                    y: isPressed ? 4 : 8
                )
                .compositingGroup()
        } else {
            shape
                .fill(fillColor(for: theme, isPressed: isPressed))
                .shadow(
                    color: shadowColor(for: theme, isPressed: isPressed),
                    radius: isPressed ? 6 : 10,
                    x: 0,
                    y: isPressed ? 4 : 7
                )
        }
    }

    private func border(for theme: AppTheme, radius: CGFloat, isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(borderColor(for: theme, isPressed: isPressed), lineWidth: 1.1)
    }

    private func highlight(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(capabilities.supportsOS26Translucency ? 0.22 : 0.14), lineWidth: 1)
            .blendMode(.screen)
    }

    // MARK: - Colors
    private func fillColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.white.opacity(isPressed ? 0.26 : 0.20)
        } else {
            return theme.resolvedTint.opacity(isPressed ? 0.32 : 0.24)
        }
    }

    private func borderColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.white.opacity(isPressed ? 0.55 : 0.42)
        } else {
            return theme.resolvedTint.opacity(isPressed ? 0.66 : 0.52)
        }
    }

    private func shadowColor(for theme: AppTheme, isPressed: Bool) -> Color {
        if theme == .system {
            return Color.black.opacity(isPressed ? 0.20 : 0.24)
        } else {
            return theme.resolvedTint.opacity(isPressed ? 0.24 : 0.30)
        }
    }

    private func foregroundColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.primary : Color.white
    }
}
