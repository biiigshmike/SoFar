// OffshoreBudgeting/Views/Components/UBSegmentedControlStyleModifier.swift

import SwiftUI

// MARK: - UBSegmentedControlStyleModifier
struct UBSegmentedControlStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        // On macOS, apply our custom styler to achieve the full-width, glass look.
        content.modifier(MacSegmentedControlStyler())
        #else
        // On other platforms, no special styling is needed for this behavior.
        content
        #endif
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
