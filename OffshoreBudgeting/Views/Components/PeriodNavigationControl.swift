// OffshoreBudgeting/Views/Components/PeriodNavigationControl.swift

import SwiftUI

/// Chevron-based navigation control for traversing budgeting periods.
struct PeriodNavigationControl: View {
    @Environment(\.platformCapabilities) private var capabilities
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    enum Style {
        case plain
        case glass
    }

    private let title: String
    private let style: Style
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    init(
        title: String,
        style: Style = .plain,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .plain:
            navigationContent
        case .glass:
            if capabilities.supportsOS26Translucency {
                RootHeaderGlassControl(width: nil) {
                    navigationContent
                }
            } else {
                navigationContent
            }
        }
    }

    private var navigationContent: some View {
        HStack(spacing: DS.Spacing.s) {
            navigationButton(systemName: "chevron.left", action: onPrevious)

            Text(title)
                .font(titleTypography.font)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(titleTypography.minimumScaleFactor)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)

            navigationButton(systemName: "chevron.right", action: onNext)
        }
    }
}

private extension PeriodNavigationControl {
    private var navigationButtonDimension: CGFloat {
        RootHeaderActionMetrics.dimension(for: capabilities)
    }

    @ViewBuilder
    private func navigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: navigationButtonDimension, height: navigationButtonDimension)
        }
        .buttonStyle(PeriodNavigationButtonStyle(capabilities: capabilities))
    }

    struct TitleTypography {
        let font: Font
        let minimumScaleFactor: CGFloat
    }

    var titleTypography: TitleTypography {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return TitleTypography(font: .title3.bold(), minimumScaleFactor: 0.6)
        }
        #endif
        return TitleTypography(font: .title2.bold(), minimumScaleFactor: 0.7)
    }
}

/// A custom button style to create circular, glass-like buttons on modern macOS.
private struct PeriodNavigationButtonStyle: ButtonStyle {
    let capabilities: PlatformCapabilities

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                // Use the modern glass material on supported OS, otherwise a legacy fill.
                Group {
                    if capabilities.supportsOS26Translucency {
                        Circle().fill(.ultraThinMaterial)
                    } else {
                        Circle().fill(Color.primary.opacity(0.1))
                    }
                }
            )
            .clipShape(Circle()) // This ensures the button is perfectly round.
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension PeriodNavigationControl.Style {
    static var glassIfAvailable: Self {
        return PlatformCapabilities.current.supportsOS26Translucency ? .glass : .plain
    }
}
