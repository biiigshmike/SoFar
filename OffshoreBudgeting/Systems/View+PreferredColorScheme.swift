import SwiftUI

extension View {
    /// Applies `preferredColorScheme(_:)` only when a non-nil scheme is provided.
    ///
    /// Passing `nil` to SwiftUI's `preferredColorScheme` can leave the previous
    /// color scheme override in place. Using this helper ensures the modifier is
    /// removed entirely when `scheme` is `nil`, allowing the view to follow the
    /// system appearance.
    @ViewBuilder
    func applyPreferredColorScheme(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            self.preferredColorScheme(scheme)
        } else {
            self
        }
    }
}
