import SwiftUI

// MARK: - UBSegmentedControlStyleModifier
struct UBSegmentedControlStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        // This modifier is now only for non-macOS platforms if needed,
        // or can be left empty. No specific macOS logic is required here anymore.
        content
    }
}

extension View {
    func ub_segmentedControlStyle() -> some View {
        modifier(UBSegmentedControlStyleModifier())
    }
}

extension AppTheme {
    var primaryAccent: Color { glassPalette.accent }
}
