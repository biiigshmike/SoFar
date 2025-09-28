import SwiftUI

// MARK: - UBSegmentedControlStyleModifier
struct UBSegmentedControlStyleModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
#if os(macOS)
        if capabilities.supportsOS26Translucency {
            content
        } else {
            content
                .controlSize(.large)
                .tint(themeManager.selectedTheme.primaryAccent)
        }
#else
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
