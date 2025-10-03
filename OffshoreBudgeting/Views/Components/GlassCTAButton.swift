import SwiftUI

// MARK: - GlassCTAButton
/// Reusable call-to-action button that automatically adopts the Liquid Glass
/// treatment on modern systems while falling back to the legacy translucent
/// styling for older platforms.
struct GlassCTAButton<Label: View>: View {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private let maxWidth: CGFloat?
    private let fillHorizontally: Bool
    private let action: () -> Void
    private let labelBuilder: () -> Label
    private let fallbackAppearance: TranslucentButtonStyle.Appearance
    private let fallbackMetrics: TranslucentButtonStyle.Metrics

    init(
        maxWidth: CGFloat? = nil,
        fillHorizontally: Bool = false,
        fallbackAppearance: TranslucentButtonStyle.Appearance = .tinted,
        fallbackMetrics: TranslucentButtonStyle.Metrics = .standard,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.maxWidth = maxWidth
        self.fillHorizontally = fillHorizontally
        self.action = action
        self.labelBuilder = label
        self.fallbackAppearance = fallbackAppearance
        self.fallbackMetrics = fallbackMetrics
    }

    var body: some View {
        Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                glassButton()
            } else {
                legacyButton()
            }
        }
        .frame(maxWidth: resolvedMaxWidth)
    }

    // MARK: - Private Helpers
    @ViewBuilder
    private func legacyButton() -> some View {
        Button(action: action) {
            labelBuilder()
        }
        .buttonStyle(
            TranslucentButtonStyle(
                tint: fallbackTint,
                metrics: resolvedFallbackMetrics,
                appearance: fallbackAppearance
            )
        )
    }

    @available(iOS 26.0, macCatalyst 26.0, *)
    @ViewBuilder
    private func glassButton() -> some View {
        Button(action: action) {
            labelBuilder()
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(glassLabelForeground)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.m)
                .frame(maxWidth: fillHorizontally ? .infinity : nil, alignment: .center)
        }
        .buttonStyle(.glass)
        .tint(glassTint)
    }

    private var fallbackTint: Color {
        themeManager.selectedTheme.resolvedTint
    }

    private var glassTint: Color {
        themeManager.selectedTheme.glassPalette.accent
    }

    private var glassLabelForeground: Color {
        colorScheme == .light ? .black : .primary
    }

    private var resolvedFallbackMetrics: TranslucentButtonStyle.Metrics {
        guard fillHorizontally else { return fallbackMetrics }
        var metrics = fallbackMetrics
        metrics.layout = .expandHorizontally
        metrics.width = nil
        return metrics
    }

    private var resolvedMaxWidth: CGFloat? {
        if let maxWidth {
            return maxWidth
        }
        return fillHorizontally ? .infinity : nil
    }
}
