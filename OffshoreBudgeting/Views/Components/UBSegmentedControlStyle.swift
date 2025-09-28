import SwiftUI

// MARK: - UBSegmentedControlStyle
/// Applies platform-aware styling to segmented controls so macOS 15.x and earlier
/// retain their tinted/buttons appearance while newer OS 26 releases use the
/// system Liquid Glass treatment automatically.
struct UBSegmentedControlStyle: ViewModifier {
    let capabilities: PlatformCapabilities
    let accentColor: Color

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
    func ubSegmentedControlStyle(capabilities: PlatformCapabilities, accentColor: Color) -> some View {
        modifier(UBSegmentedControlStyle(capabilities: capabilities, accentColor: accentColor))
    }
}
