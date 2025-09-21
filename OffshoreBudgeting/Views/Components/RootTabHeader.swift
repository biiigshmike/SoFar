import SwiftUI

/// Shared header for root tab screens. Ensures a large, bold title is consistently
/// rendered across platforms while leaving space for optional trailing controls
/// (such as summary buttons or quick actions).
struct RootTabHeader<Trailing: View>: View {
    // MARK: Properties
    @Environment(\.ub_safeAreaInsets) private var safeAreaInsets
    private let title: String
    private let horizontalPadding: CGFloat
    @ViewBuilder private let trailing: () -> Trailing

    /// Shared default padding value so other "planes" can align with the title row.
    static let defaultHorizontalPadding: CGFloat = DS.Spacing.l

    // MARK: Init
    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeader.defaultHorizontalPadding,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.trailing = trailing
    }

    init(title: String, horizontalPadding: CGFloat = RootTabHeader.defaultHorizontalPadding) where Trailing == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.trailing = { EmptyView() }
    }

    // MARK: Body
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
    }

    private var topPadding: CGFloat {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return DS.Spacing.l
        #else
        let basePadding = DS.Spacing.xxl

        let adjusted = safeAreaInsets.top + DS.Spacing.m
        return max(basePadding, adjusted)

        let safeAreaTop = safeAreaInsets.top

        guard safeAreaTop > 0 else { return basePadding }
        return max(basePadding, safeAreaTop + DS.Spacing.m)

        #endif
    }
}
