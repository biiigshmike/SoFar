import SwiftUI

/// Provides a consistent header for root tab screens, keeping the large title and
/// optional trailing actions aligned on the same horizontal plane.
struct RootViewTopPlanes<ActionContent: View>: View {
    private let title: String
    private let horizontalPadding: CGFloat
    private let actionContent: ActionContent?

    init(title: String, horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding) where ActionContent == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = nil
    }

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        @ViewBuilder actions: () -> ActionContent
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = actions()
    }

    @ViewBuilder
    var body: some View {
        if let actionContent {
            RootTabHeader(title: title, horizontalPadding: horizontalPadding) {
                actionContent
            }
        } else {
            RootTabHeader(title: title, horizontalPadding: horizontalPadding)
        }
    }
}
