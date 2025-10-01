import SwiftUI

#if os(iOS)
import UIKit

/// Tames UIKit's automatic bottom inset adjustments for the nearest ancestor
/// `UIScrollView` (the one backing a SwiftUI `ScrollView`). On legacy iOS
/// versions, SwiftUI/UIScrollView will add extra bottom insets so content
/// stays above the tab bar. That’s desirable for many screens, but our root
/// tab pages manage bottom spacing themselves via `RootTabPageScaffold`.
///
/// Previously we disabled all automatic inset adjustments by setting
/// `contentInsetAdjustmentBehavior = .never`. That also turned off the top
/// inset management performed by UIKit, which could cause content to slide
/// underneath the navigation bar, leaving the bar’s background looking
/// transparent when lists are scrolled. To preserve the correct navigation
/// chrome while still neutralizing the unwanted bottom padding, this helper
/// now leaves the adjustment behavior as-is and only zeroes the bottom
/// content/indicator insets.
struct UBScrollViewInsetAdjustmentDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let scrollView = findEnclosingScrollView(from: uiView) else { return }

        // Keep UIKit's automatic top inset handling intact so the navigation
        // bar continues to render its opaque background correctly when titles
        // collapse. Only neutralize the bottom padding that pushes content
        // above the tab bar; `RootTabPageScaffold` provides its own spacing.
        if #available(iOS 15.0, *) {
            // Avoid iOS automatically altering indicator insets at the bottom.
            scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }

        // Ensure bottom insets aren't lingering from previous adjustments.
        if scrollView.contentInset.bottom != 0 {
            scrollView.contentInset.bottom = 0
        }
        if scrollView.verticalScrollIndicatorInsets.bottom != 0 {
            scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    private func findEnclosingScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        // Walk up the view hierarchy to find the nearest UIScrollView.
        while let v = current?.superview {
            if let sv = v as? UIScrollView { return sv }
            current = v
        }
        return nil
    }
}
#endif
