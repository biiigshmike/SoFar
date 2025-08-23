import SwiftUI

// MARK: - AppHint
/// Metadata describing a contextual hint attached to a particular view.
/// `id` should be unique across the app.
struct AppHint: Identifiable {
    let id: String
    let title: String
    let message: String
    var actionTitle: String = "Got it"
}
