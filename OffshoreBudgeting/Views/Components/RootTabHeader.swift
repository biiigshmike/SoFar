import SwiftUI

/// Shared layout values for ``RootTabHeader`` and aligned components.
enum RootTabHeaderLayout {
    static let defaultHorizontalPadding: CGFloat = DS.Spacing.l
    enum TopPaddingStyle {
        case standard
        case navigationBarAligned
        case contentEmbedded
    }
    enum TrailingPlacement {
        /// Default: title expands to fill and trailing controls are pinned right.
        case right
        /// Title and trailing controls are placed inline then pushed left together.
        case inline
    }
}

/// Shared header for root tab screens. Ensures a large, bold title is consistently
/// rendered across platforms while leaving space for optional trailing controls
/// (such as summary buttons or quick actions).
struct RootTabHeader<Trailing: View>: View {
    // MARK: Properties
    @Environment(\.ub_safeAreaInsets) private var safeAreaInsets
    @Environment(\.responsiveLayoutContext) private var responsiveLayoutContext
    private let title: String?
    private let horizontalPadding: CGFloat
    private let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle
    private let trailingPlacement: RootTabHeaderLayout.TrailingPlacement
    @ViewBuilder private let trailing: () -> Trailing

    // MARK: Init
    init(
        title: String?,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
        self.trailing = trailing
    }

    init(
        title: String?,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right
    ) where Trailing == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
        self.trailing = { EmptyView() }
    }

    // MARK: Body
    var body: some View {
        headerStack
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, resolvedTopPadding)
    }

    private var headerStack: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            if let title {
                Text(title)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: trailingPlacement == .right ? .infinity : nil, alignment: .leading)
            } else if trailingPlacement == .right {
                Spacer(minLength: 0)
            }

            trailing()

            if trailingPlacement == .inline {
                Spacer(minLength: 0)
            }
        }
    }

    private var resolvedTopPadding: CGFloat {
        switch topPaddingStyle {
        case .standard:
            return standardTopPadding
        case .navigationBarAligned:
            return navigationBarAlignedTopPadding
        case .contentEmbedded:
            return contentEmbeddedTopPadding
        }
    }

    private var standardTopPadding: CGFloat {
        #if targetEnvironment(macCatalyst)
        return DS.Spacing.l
        #else
        // Respect top safe area on iOS/iPadOS to avoid overlapping the status bar.
        return effectiveSafeAreaInsets.top + DS.Spacing.l
        #endif
    }

    private var navigationBarAlignedTopPadding: CGFloat {
        #if targetEnvironment(macCatalyst)
        return DS.Spacing.l
        #else
        // Keep parity with standard for now; can be tweaked to align with a nav bar if needed.
        return effectiveSafeAreaInsets.top + DS.Spacing.l
        #endif
    }

    private var contentEmbeddedTopPadding: CGFloat {
        DS.Spacing.l
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
