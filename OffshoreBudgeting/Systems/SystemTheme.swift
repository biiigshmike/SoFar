import SwiftUI
import UIKit

/// Central adapter that decides whether the system should use Liquid Glass (OS 26
/// cycle) or Classic styling (earlier OS versions), and applies minimal global
/// chrome where appropriate for legacy systems.
enum SystemThemeAdapter {
    enum Flavor { case liquid, classic }

    static var currentFlavor: Flavor {
        if #available(iOS 18.0, macCatalyst 18.0, *) {
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

        let backgroundColor = resolvedBackgroundColor(for: theme, colorScheme: colorScheme)

        // UINavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = backgroundColor
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // UIToolbar (avoid custom backgrounds on OS 26; safe on classic)
        let toolAppearance = UIToolbarAppearance()
        toolAppearance.configureWithOpaqueBackground()
        toolAppearance.backgroundColor = backgroundColor
        UIToolbar.appearance().standardAppearance = toolAppearance
        UIToolbar.appearance().compactAppearance = toolAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolAppearance

        // UITabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = backgroundColor
        tabAppearance.shadowColor = nil
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.compactAppearance = tabAppearance
    }

    private static func resolvedBackgroundColor(for theme: AppTheme, colorScheme: ColorScheme?) -> UIColor {
        guard let scheme = colorScheme else {
            return UIColor(theme.background)
        }

        let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
        let trait = UITraitCollection(userInterfaceStyle: style)
        return UIColor(theme.background).resolvedColor(with: trait)
    }
}

