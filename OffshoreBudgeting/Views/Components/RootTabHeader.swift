import SwiftUI

/// Shared layout values for ``RootTabHeader`` and aligned components.
enum RootTabHeaderLayout {
    static let defaultHorizontalPadding: CGFloat = DS.Spacing.l
    enum TopPaddingStyle {
        case standard
        case navigationBarAligned
    }
}

/// Shared header for root tab screens. Ensures a large, bold title is consistently
/// rendered across platforms while leaving space for optional trailing controls
/// (such as summary buttons or quick actions).
struct RootTabHeader<Trailing: View>: View {
    // MARK: Properties
    @Environment(\.ub_safeAreaInsets) private var safeAreaInsets
    @Environment(\.responsiveLayoutContext) private var responsiveLayoutContext
    private let title: String
    private let horizontalPadding: CGFloat
    private let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle
    @ViewBuilder private let trailing: () -> Trailing

    // MARK: Init
    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.topPaddingStyle = topPaddingStyle
        self.trailing = trailing
    }

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard
    ) where Trailing == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.topPaddingStyle = topPaddingStyle
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
        .padding(.top, resolvedTopPadding)
    }

    private var resolvedTopPadding: CGFloat {
        switch topPaddingStyle {
        case .standard:
            return standardTopPadding
        case .navigationBarAligned:
            return navigationBarAlignedTopPadding
        }
    }

    private var standardTopPadding: CGFloat {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return DS.Spacing.l
        #else
        let basePadding = DS.Spacing.xxl
        let adjusted = effectiveSafeAreaInsets.top + DS.Spacing.m
        return max(basePadding, adjusted)
        #endif
    }

    private var navigationBarAlignedTopPadding: CGFloat {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return DS.Spacing.l
        #else
        let adjusted = effectiveSafeAreaInsets.top + DS.Spacing.xs
        return max(DS.Spacing.l, adjusted)
        #endif
    }

    private var effectiveSafeAreaInsets: EdgeInsets {
        if safeAreaInsets.hasNonZeroInsets {
            return safeAreaInsets
        }

        let contextInsets = responsiveLayoutContext.safeArea
        if contextInsets.hasNonZeroInsets {
            return contextInsets
        }

        return safeAreaInsets
    }
}
