#if os(macOS)
import SwiftUI

extension View {
    @ViewBuilder
    func macLegacyAccentTintIfNeeded(
        capabilities: PlatformCapabilities,
        accentColor: Color
    ) -> some View {
        if capabilities.supportsOS26Translucency {
            self
        } else {
            self.tint(accentColor)
        }
    }
}
#endif
