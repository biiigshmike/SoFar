import SwiftUI

// MARK: - AppHintViewModifier
/// Attaches a contextual hint to any view. When the view appears the
/// `AppTourManager` decides whether to show the hint.
struct AppHintViewModifier: ViewModifier {
    @EnvironmentObject private var tourManager: AppTourManager
    let hint: AppHint

    func body(content: Content) -> some View {
        content.onAppear { tourManager.present(hint: hint) }
    }
}

// MARK: - View+AppHint
extension View {
    /// Attach a contextual hint that is displayed once per installation.
    /// - Parameter hint: `AppHint` describing the content of the hint.
    func appHint(_ hint: AppHint) -> some View {
        modifier(AppHintViewModifier(hint: hint))
    }
}
