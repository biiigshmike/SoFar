import SwiftUI

/// Provides a cross-platform safe area inset reader that mirrors the behaviour
/// of the `EnvironmentValues.safeAreaInsets` value introduced in newer SwiftUI
/// releases. Views can opt into the reader via `ub_captureSafeAreaInsets()` and
/// then access the resolved insets using `@Environment(\.ub_safeAreaInsets)`.

private struct UBSafeAreaInsetsEnvironmentKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    /// Back-deployed safe area inset environment value. The project previously
    /// relied on `EnvironmentValues.safeAreaInsets`, however that API is only
    /// available on the most recent SDKs which caused compilation failures on
    /// older toolchains. By providing our own key we can continue to query the
    /// insets in a consistent manner across iOS, iPadOS, macOS and Mac Catalyst.
    var ub_safeAreaInsets: EdgeInsets {
        get { self[UBSafeAreaInsetsEnvironmentKey.self] }
        set { self[UBSafeAreaInsetsEnvironmentKey.self] = newValue }
    }
}

private struct UBSafeAreaInsetsPreferenceKey: PreferenceKey {
    static var defaultValue = EdgeInsets()

    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

private struct UBSafeAreaInsetsReader: ViewModifier {
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        content
            .environment(\.ub_safeAreaInsets, insets)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: UBSafeAreaInsetsPreferenceKey.self, value: proxy.safeAreaInsets)
                }
            )
            .onPreferenceChange(UBSafeAreaInsetsPreferenceKey.self) { value in
                guard insets != value else { return }
                insets = value
            }
    }
}

extension View {
    /// Injects the current view's safe area insets into the environment so that
    /// descendants can query `@Environment(\.ub_safeAreaInsets)` without
    /// directly depending on the newest SwiftUI APIs.
    func ub_captureSafeAreaInsets() -> some View {
        modifier(UBSafeAreaInsetsReader())
    }
}
