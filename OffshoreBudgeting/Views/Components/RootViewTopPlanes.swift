import SwiftUI

/// Provides a consistent two-plane layout for root tab screens.
/// - Plane 1: the large title rendered by ``RootTabHeader``.
/// - Plane 2: optional trailing actions/buttons aligned to the same horizontal padding.
struct RootViewTopPlanes<ActionContent: View>: View {
    private let title: String
    private let horizontalPadding: CGFloat
    private let actionContent: ActionContent?

    init(title: String, horizontalPadding: CGFloat = RootTabHeader.defaultHorizontalPadding) where ActionContent == EmptyView {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = nil
    }

    init(
        title: String,
        horizontalPadding: CGFloat = RootTabHeader.defaultHorizontalPadding,
        @ViewBuilder actions: () -> ActionContent
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.actionContent = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: actionPlaneSpacing) {
            RootTabHeader(title: title, horizontalPadding: horizontalPadding)

            if let actionContent {
                actionContent
                    .padding(.horizontal, horizontalPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionPlaneSpacing: CGFloat {
        actionContent == nil ? 0 : DS.Spacing.s
    }
}
