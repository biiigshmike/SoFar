import SwiftUI

/// Chevron-based navigation control for traversing budgeting periods.
///
/// Displays backward/forward buttons around a centered title. The control
/// mirrors the layout previously embedded within ``HomeView`` so both platforms
/// share a consistent period navigation experience.
struct PeriodNavigationControl: View {
    @Environment(\.platformCapabilities) private var capabilities
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    enum Style {
        case plain
        case glass
    }

    // MARK: - Properties
    private let title: String
    private let style: Style
    private let onPrevious: () -> Void
    private let onNext: () -> Void
    private let glassEffectID: AnyHashable?

    // MARK: - Init
    init(
        title: String,
        style: Style = .plain,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        glassEffectID: AnyHashable? = nil
    ) {
        self.title = title
        self.style = style
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.glassEffectID = glassEffectID
    }

    // MARK: - Body
    @ViewBuilder
    var body: some View {
        switch style {
        case .plain:
            plainContent

        case .glass:
#if os(iOS) || os(macOS)
            if capabilities.supportsOS26Translucency {
                RootHeaderGlassControl(width: nil, effectID: glassEffectID) {
                    navigationContent
                }
            } else {
                plainContent
            }
#else
            plainContent
#endif
        }
    }

    private var plainContent: some View {
        navigationContent
    }

    @ViewBuilder
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

// MARK: - Typography Helpers

private extension PeriodNavigationControl {
    private var navigationButtonDimension: CGFloat {
        RootHeaderActionMetrics.dimension(for: capabilities)
    }

    @ViewBuilder
    private func navigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .frame(width: navigationButtonDimension, height: navigationButtonDimension)
        .contentShape(Rectangle())
        .periodNavigationButtonStyle(capabilities: capabilities)
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

// MARK: - Button Styling Helpers

private extension View {
    @ViewBuilder
    func periodNavigationButtonStyle(capabilities: PlatformCapabilities) -> some View {
#if swift(>=6.0)
        if capabilities.supportsOS26Translucency {
            if #available(iOS 18.0, macOS 26.0, tvOS 18.0, visionOS 2.0, watchOS 11.0, macCatalyst 26.0, *) {
                buttonStyle(.glass)
            } else {
                buttonStyle(.plain)
            }
        } else {
            buttonStyle(.plain)
        }
#else
        buttonStyle(.plain)
#endif
    }
}

extension PeriodNavigationControl.Style {
    static var glassIfAvailable: Self {
#if os(iOS) || os(macOS)
        return PlatformCapabilities.current.supportsOS26Translucency ? .glass : .plain
#else
        return .plain
#endif
    }
}
