import SwiftUI

/// Provides a consistent header for root tab screens, keeping the large title and
/// optional trailing actions aligned on the same horizontal plane.
struct RootViewTopPlanes<ActionContent: View>: View {
    private let title: String
    private let horizontalPadding: CGFloat
    private let actionContent: ActionContent?
    private let topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard
    ) where ActionContent == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = nil
        self.topPaddingStyle = topPaddingStyle
    }

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        topPaddingStyle: RootTabHeaderLayout.TopPaddingStyle = .standard,
        @ViewBuilder actions: () -> ActionContent
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = actions()
        self.topPaddingStyle = topPaddingStyle
    }

    @ViewBuilder
    var body: some View {
        if let actionContent {
            RootTabHeader(
                title: title,
                horizontalPadding: horizontalPadding,
                topPaddingStyle: topPaddingStyle
            ) {
                actionContent
            }
        } else {
            RootTabHeader(
                title: title,
                horizontalPadding: horizontalPadding,
                topPaddingStyle: topPaddingStyle
            )
        }
    }
}
