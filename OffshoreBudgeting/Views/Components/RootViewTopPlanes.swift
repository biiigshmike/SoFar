import SwiftUI

/// Provides a consistent header for root tab screens, keeping the large title and
/// optional trailing actions aligned on the same horizontal plane.
struct RootViewTopPlanes<ActionContent: View>: View {
    enum TitleDisplayMode {
        case visible
        case hidden
    }

    private let resolvedTitle: String?
    private let horizontalPadding: CGFloat
    private let actionContent: ActionContent?
    private let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle
    private let trailingPlacement: RootTabHeaderLayout.TrailingPlacement

    init(
        title: String,
        titleDisplayMode: TitleDisplayMode = .visible,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right
    ) where ActionContent == EmptyView {
        self.resolvedTitle = Self.resolveTitle(title, for: titleDisplayMode)
        self.horizontalPadding = horizontalPadding
        self.actionContent = nil
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
    }

    init(
        title: String,
        titleDisplayMode: TitleDisplayMode = .visible,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right,
        @ViewBuilder actions: () -> ActionContent
    ) {
        self.resolvedTitle = Self.resolveTitle(title, for: titleDisplayMode)
        self.horizontalPadding = horizontalPadding
        self.actionContent = actions()
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
    }

    @ViewBuilder
    var body: some View {
        if resolvedTitle != nil || actionContent != nil {
            if let actionContent {
                RootTabHeader(
                    title: resolvedTitle,
                    horizontalPadding: horizontalPadding,
                    topPaddingStyle: topPaddingStyle,
                    trailingPlacement: trailingPlacement
                ) {
                    actionContent
                }
            } else {
                RootTabHeader(
                    title: resolvedTitle,
                    horizontalPadding: horizontalPadding,
                    topPaddingStyle: topPaddingStyle,
                    trailingPlacement: trailingPlacement
                )
            }
        }
    }

    private static func resolveTitle(_ title: String, for mode: TitleDisplayMode) -> String? {
        switch mode {
        case .visible:
            return title
        case .hidden:
            return nil
        }
    }
}
