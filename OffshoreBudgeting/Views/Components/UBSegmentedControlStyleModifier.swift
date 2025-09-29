// OffshoreBudgeting/Views/Components/UBSegmentedControlStyleModifier.swift

import SwiftUI

// MARK: - UBSegmentedControlStyleModifier
struct UBSegmentedControlStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Segment styling now relies on the default UIKit appearance across all supported platforms.
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
