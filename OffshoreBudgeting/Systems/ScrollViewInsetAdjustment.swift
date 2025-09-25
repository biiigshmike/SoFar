import SwiftUI

#if os(iOS)
import UIKit

/// Disables UIKit's automatic content inset adjustments for the nearest
/// ancestor `UIScrollView` (the one backing a SwiftUI `ScrollView`).
///
/// Place this view inside a `ScrollView` content hierarchy to avoid implicit
/// bottom padding that UIKit inserts to keep content above bars.
struct UBScrollViewInsetAdjustmentDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let scrollView = findEnclosingScrollView(from: uiView) else { return }
        if scrollView.contentInsetAdjustmentBehavior != .never {
            scrollView.contentInsetAdjustmentBehavior = .never
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

