import SwiftUI

/// Runtime-evaluated feature toggles that describe which platform niceties are
/// available on the current device. Inject a single instance at the app entry
/// point so that every scene and modifier can consult the same source of
/// truth when opting into newer system behaviours.
struct PlatformCapabilities: Equatable {
    /// Whether the current OS supports the refreshed translucent chrome
    /// treatments Apple shipped alongside the OS 26 cycle (iOS/iPadOS,
    /// macCatalyst, visionOS 2, etc.).
    let supportsOS26Translucency: Bool

    /// Whether the adaptive numeric keyboard layout from OS 26 is available on
    /// this device. Only meaningful on iOS builds.
    let supportsAdaptiveKeypad: Bool
}

extension PlatformCapabilities {
    /// Snapshot the current process' capabilities using the most specific
    /// availability information we have at launch.
    static var current: PlatformCapabilities {
        let supportsModernTranslucency: Bool
        // Liquid Glass is available starting with the OS 26 system releases.
        if #available(iOS 18.0, macCatalyst 18.0, *) {
            supportsModernTranslucency = true
        } else {
            supportsModernTranslucency = false
        }

        #if targetEnvironment(macCatalyst)
        let supportsAdaptiveKeypad = false
        #else
        let supportsAdaptiveKeypad = supportsModernTranslucency
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
