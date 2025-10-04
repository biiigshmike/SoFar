import SwiftUI
import UIKit

/// Central adapter that decides whether the system should use Liquid Glass (OS 26
/// cycle) or Classic styling (earlier OS versions), and applies minimal global
/// chrome where appropriate for legacy systems.
enum SystemThemeAdapter {
    enum Flavor { case liquid, classic }

    static var currentFlavor: Flavor {
        // Treat OS 26 as the threshold for the native Liquid Glass cycle.
        if #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
            return .liquid
        } else {
            return .classic
        }
    }

    /// Apply minimal, system-friendly global chrome. On OS 26 we avoid
    /// overriding system appearances per Apple guidance. On earlier OS versions,
    /// we set plain, opaque backgrounds to respect the classic, flat style.
    static func applyGlobalChrome(theme: AppTheme, colorScheme: ColorScheme?) {
        // Always prefer large titles so OS26 shows the big title on initial load.
        UINavigationBar.appearance().prefersLargeTitles = true

        guard currentFlavor == .classic else { return }

        // UINavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = theme.legacyUIKitChromeBackgroundColor(colorScheme: colorScheme)
        // Ensure readable titles/buttons for classic (opaque) chrome.
        let resolvedTitleColor = resolvedForegroundColor(for: theme, colorScheme: colorScheme)
        navAppearance.titleTextAttributes = [.foregroundColor: resolvedTitleColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: resolvedTitleColor]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().isTranslucent = false

        // UIToolbar (avoid custom backgrounds on OS 26; safe on classic)
        let toolAppearance = UIToolbarAppearance()
        toolAppearance.configureWithOpaqueBackground()
        let resolvedBackground = theme.legacyUIKitChromeBackgroundColor(colorScheme: colorScheme)
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
        UITabBar.appearance().isTranslucent = false
    }

    private static func resolvedForegroundColor(
        for theme: AppTheme,
        colorScheme: ColorScheme?
    ) -> UIColor {
        // On classic chrome, prefer white text for dark mode backgrounds.
        // For light mode, prefer black text. This keeps titles readable
        // against the legacy chrome backgrounds computed above.
        if let scheme = colorScheme {
            return (scheme == .dark) ? UIColor.white : UIColor.black
        }
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        return isDark ? UIColor.white : UIColor.black
    }
}
