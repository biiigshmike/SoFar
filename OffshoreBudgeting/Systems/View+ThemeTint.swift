import SwiftUI

extension View {
    /// Applies the application's themed accent color when the caller needs to
    /// override the system tint. When `shouldApply` is false, the modifier is a
    /// no-op so that platform-native styling can show through.
    @ViewBuilder
    func ub_themeAccentColor(_ color: Color, when shouldApply: Bool) -> some View {
        if shouldApply {
            self
                .accentColor(color)
                .tint(color)
        } else {
            self
        }
    }

    /// Applies the app's theme tint to controls that still need explicit
    /// coloring (e.g., legacy macOS, iOS). When `shouldApply` is false, the view
    /// is returned unchanged.
    @ViewBuilder
    func ub_themeTint(_ color: Color, when shouldApply: Bool) -> some View {
        if shouldApply {
            self.tint(color)
        } else {
            self
        }
    }
}
