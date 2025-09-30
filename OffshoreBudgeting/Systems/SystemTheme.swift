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

        let backgroundColor: UIColor = {
            if let scheme = colorScheme {
                let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
                let trait = UITraitCollection(userInterfaceStyle: style)
                return UIColor(theme.background).resolvedColor(with: trait)
            } else {
                return UIColor(theme.background)
            }
        }()

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
        let tabPalette = theme.tabBarPalette
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = backgroundColor

        func configureTabItemAppearance(_ itemAppearance: UITabBarItemAppearance) {
            let activeColor = UIColor(tabPalette.active)
            let inactiveColor = UIColor(tabPalette.inactive)
            let disabledColor = UIColor(tabPalette.disabled)
            let badgeBackground = UIColor(tabPalette.badgeBackground)
            let badgeForeground = UIColor(tabPalette.badgeForeground)

            itemAppearance.selected.iconColor = activeColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: activeColor
            ]
            itemAppearance.selected.badgeBackgroundColor = badgeBackground
            itemAppearance.selected.badgeTextAttributes = [
                .foregroundColor: badgeForeground
            ]

            itemAppearance.normal.iconColor = inactiveColor
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: inactiveColor
            ]
            itemAppearance.normal.badgeBackgroundColor = badgeBackground
            itemAppearance.normal.badgeTextAttributes = [
                .foregroundColor: badgeForeground
            ]

            itemAppearance.disabled.iconColor = disabledColor
            itemAppearance.disabled.titleTextAttributes = [
                .foregroundColor: disabledColor
            ]
            itemAppearance.disabled.badgeBackgroundColor = badgeBackground
            itemAppearance.disabled.badgeTextAttributes = [
                .foregroundColor: badgeForeground
            ]

            itemAppearance.focused.iconColor = activeColor
            itemAppearance.focused.titleTextAttributes = [
                .foregroundColor: activeColor
            ]
            itemAppearance.focused.badgeBackgroundColor = badgeBackground
            itemAppearance.focused.badgeTextAttributes = [
                .foregroundColor: badgeForeground
            ]
        }

        configureTabItemAppearance(tabAppearance.stackedLayoutAppearance)
        configureTabItemAppearance(tabAppearance.inlineLayoutAppearance)
        configureTabItemAppearance(tabAppearance.compactInlineLayoutAppearance)

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(tabPalette.active)
        UITabBar.appearance().unselectedItemTintColor = UIColor(tabPalette.inactive)
    }
}

