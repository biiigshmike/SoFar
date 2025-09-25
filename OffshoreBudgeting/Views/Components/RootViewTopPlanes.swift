import SwiftUI

/// Provides a consistent header for root tab screens, keeping the large title and
/// optional trailing actions aligned on the same horizontal plane.
struct RootViewTopPlanes<ActionContent: View>: View {
    private let title: String
    private let horizontalPadding: CGFloat
    private let actionContent: ActionContent?
    private let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle
    private let trailingPlacement: RootTabHeaderLayout.TrailingPlacement

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right
    ) where ActionContent == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = nil
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
    }

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        trailingPlacement: RootTabHeaderLayout.TrailingPlacement = .right,
        @ViewBuilder actions: () -> ActionContent
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = actions()
        self.topPaddingStyle = topPaddingStyle
        self.trailingPlacement = trailingPlacement
    }

    @ViewBuilder
    var body: some View {
        if let actionContent {
            RootTabHeader(
                title: title,
                horizontalPadding: horizontalPadding,
                topPaddingStyle: topPaddingStyle,
                trailingPlacement: trailingPlacement
            ) {
                actionContent
            }
        } else {
            RootTabHeader(
                title: title,
                horizontalPadding: horizontalPadding,
                topPaddingStyle: topPaddingStyle,
                trailingPlacement: trailingPlacement
            )
        }
    }
}
