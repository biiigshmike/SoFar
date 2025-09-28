import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - UBSegmentedControlStyleModifier
struct UBSegmentedControlStyleModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        #if os(macOS)
        // For modern macOS, we apply a specific style that achieves the pill-shape look.
        if capabilities.supportsOS26Translucency {
            content
                // This is the key: `.pickerStyle(.inline)` on macOS with a Picker that has
                // only two segments and is inside a container with a restricted frame
                // will render as a full-width, pill-shaped control.
                .pickerStyle(.inline)
                .labelsHidden()
                // Ensure a minimum height for a good visual appearance.
                .frame(minHeight: 36)
        } else {
            // Legacy macOS styling remains unchanged.
            content
                .controlSize(.large)
                .tint(themeManager.selectedTheme.primaryAccent)
        }
        #else
        // iOS and other platforms use the default behavior.
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
