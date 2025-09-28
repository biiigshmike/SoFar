import SwiftUI

// MARK: - LiquidAwareSegmentedControlStyle
struct LiquidAwareSegmentedControlStyle: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let accentColor: Color

    init(accentColor: Color = .accentColor) {
        self.accentColor = accentColor
    }

    func body(content: Content) -> some View {
#if os(macOS)
        if capabilities.supportsOS26Translucency {
            content
        } else {
            content
                .controlSize(.large)
                .tint(accentColor)
        }
#else
        content
#endif
    }
}

extension View {
    func liquidAwareSegmentedControlStyle(accentColor: Color = .accentColor) -> some View {
        modifier(LiquidAwareSegmentedControlStyle(accentColor: accentColor))
    }
}
