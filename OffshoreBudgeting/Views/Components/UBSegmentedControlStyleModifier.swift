import SwiftUI

struct UBSegmentedControlStyleModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

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
