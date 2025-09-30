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

        // UINavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = resolvedBackgroundColor(
            for: theme,
            colorScheme: colorScheme
        )
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // UIToolbar (avoid custom backgrounds on OS 26; safe on classic)
        let toolAppearance = UIToolbarAppearance()
        toolAppearance.configureWithOpaqueBackground()
        let resolvedBackground = resolvedBackgroundColor(
            for: theme,
            colorScheme: colorScheme
        )
        toolAppearance.backgroundColor = resolvedBackground
        UIToolbar.appearance().standardAppearance = toolAppearance
        UIToolbar.appearance().compactAppearance = toolAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolAppearance

        // UITabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = resolvedBackground
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    private static func resolvedBackgroundColor(
        for theme: AppTheme,
        colorScheme: ColorScheme?
    ) -> UIColor {
        if let scheme = colorScheme {
            let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
            let trait = UITraitCollection(userInterfaceStyle: style)
            return UIColor(theme.background).resolvedColor(with: trait)
        }

        return UIColor(theme.background)
    }
}

