import SwiftUI

/// Chevron-based navigation control for traversing budgeting periods.
///
/// Displays backward/forward buttons around a centered title. The control
/// mirrors the layout previously embedded within ``HomeView`` so both platforms
/// share a consistent period navigation experience.
struct PeriodNavigationControl: View {
    @Environment(\.platformCapabilities) private var capabilities
    enum Style {
        case plain
        case glass
    }

    // MARK: - Properties
    private let title: String
    private let style: Style
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    // MARK: - Init
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

    // MARK: - Body
    @ViewBuilder
    var body: some View {
        switch style {
        case .plain:
            plainContent

        case .glass:
#if os(iOS) || os(macOS)
            if capabilities.supportsOS26Translucency {
                RootHeaderGlassControl(width: nil) {
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
        let buttonDimension = RootHeaderActionMetrics.dimension

        HStack(spacing: DS.Spacing.s) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .frame(width: buttonDimension, height: buttonDimension)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .frame(width: buttonDimension, height: buttonDimension)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
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
