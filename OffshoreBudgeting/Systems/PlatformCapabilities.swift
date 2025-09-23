import SwiftUI

/// Runtime-evaluated feature toggles that describe which platform niceties are
/// available on the current device. Inject a single instance at the app entry
/// point so that every scene and modifier can consult the same source of
/// truth when opting into newer system behaviours.
struct PlatformCapabilities: Equatable {
    /// Whether the current OS supports the refreshed OS 26 translucent chrome
    /// treatments introduced alongside the latest system releases.
    let supportsOS26Translucency: Bool

    /// Whether the adaptive numeric keyboard layout from OS 26 is available on
    /// this device. Only meaningful on iOS/iPadOS builds.
    let supportsAdaptiveKeypad: Bool
}

extension PlatformCapabilities {
    /// Snapshot the current process' capabilities using the most specific
    /// availability information we have at launch.
    static var current: PlatformCapabilities {
        let supportsModernTranslucency: Bool
        if #available(iOS 26.0, tvOS 26.0, macOS 15.0, macCatalyst 18.0, *) {
            supportsModernTranslucency = true
        } else {
            supportsModernTranslucency = false
        }

        #if os(iOS) || os(tvOS)
        let supportsAdaptiveKeypad = supportsModernTranslucency
        #else
        let supportsAdaptiveKeypad = false
        #endif

        return PlatformCapabilities(
            supportsOS26Translucency: supportsModernTranslucency,
            supportsAdaptiveKeypad: supportsAdaptiveKeypad
        )
    }

    /// Baseline set of capabilities used as a default value in the environment.
    static let fallback = PlatformCapabilities(supportsOS26Translucency: false, supportsAdaptiveKeypad: false)
}

// MARK: - Environment support

private struct PlatformCapabilitiesKey: EnvironmentKey {
    static let defaultValue: PlatformCapabilities = .fallback
}

extension EnvironmentValues {
    var platformCapabilities: PlatformCapabilities {
        get { self[PlatformCapabilitiesKey.self] }
        set { self[PlatformCapabilitiesKey.self] = newValue }
    }
}
