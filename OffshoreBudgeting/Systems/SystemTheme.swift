import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Central adapter that decides whether the system should use Liquid Glass (OS 26)
/// or Classic styling (earlier OS versions), and applies minimal global chrome
/// where appropriate for legacy systems.
enum SystemThemeAdapter {
    enum Flavor { case liquid, classic }

    static var currentFlavor: Flavor {
        if #available(iOS 26.0, tvOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
            return .liquid
        } else {
            return .classic
        }
    }

    /// Apply minimal, system-friendly global chrome. On OS 26 we avoid
    /// overriding system appearances per Apple guidance. On earlier OS versions,
    /// we set plain, opaque backgrounds to respect the classic, flat style.
    static func applyGlobalChrome(theme: AppTheme, colorScheme: ColorScheme?) {
        guard currentFlavor == .classic else { return }

        #if canImport(UIKit)
        // UINavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        if let scheme = colorScheme {
            let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
            let trait = UITraitCollection(userInterfaceStyle: style)
            let ui = UIColor(theme.background).resolvedColor(with: trait)
            navAppearance.backgroundColor = ui
        } else {
            navAppearance.backgroundColor = UIColor(theme.background)
        }
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // UIToolbar (avoid custom backgrounds on OS 26; safe on classic)
        let toolAppearance = UIToolbarAppearance()
        toolAppearance.configureWithOpaqueBackground()
        if let scheme = colorScheme {
            let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
            let trait = UITraitCollection(userInterfaceStyle: style)
            let ui = UIColor(theme.background).resolvedColor(with: trait)
            toolAppearance.backgroundColor = ui
        } else {
            toolAppearance.backgroundColor = UIColor(theme.background)
        }
        UIToolbar.appearance().standardAppearance = toolAppearance
        UIToolbar.appearance().compactAppearance = toolAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolAppearance
        #endif
    }
}

