//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var platformCapabilities
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            navigationContainer { HomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Home", systemImage: "house") }

            navigationContainer { IncomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Income", systemImage: "calendar") }

            navigationContainer { CardsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Cards", systemImage: "creditcard") }

            navigationContainer { PresetsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            navigationContainer { SettingsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        // Give the tab chrome its own glass background so macOS matches iOS.
        .ub_chromeBackground(
            theme: themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration
        )
        // Keep the page background as well.
        .ub_surfaceBackground(
            themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
        .onAppear(perform: updateTabBarAppearance)
        .onChange(of: themeManager.selectedTheme) { _ in
            updateTabBarAppearance()
        }
        .onChange(of: colorScheme) { _ in
            updateTabBarAppearance()
        }
        .onChange(of: platformCapabilities) { _ in
            updateTabBarAppearance()
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                #if os(iOS)
                .navigationViewStyle(StackNavigationViewStyle())
                #endif
        }
    }

    /// Ensures the tab bar matches the current theme and hides the default top border.
    private func updateTabBarAppearance() {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            let appearance = UITabBarAppearance()
            let theme = themeManager.selectedTheme
            let palette = theme.tabBarPalette

            if theme.usesGlassMaterials && platformCapabilities.supportsOS26Translucency {
                appearance.configureWithTransparentBackground()
                let configuration = themeManager.glassConfiguration
                let blurStyle = configuration.glass.material.uiBlurEffectStyle
                appearance.backgroundEffect = UIBlurEffect(style: blurStyle)

                let baseColor = theme.glassBaseColor
                let opacity = CGFloat(min(configuration.liquid.tintOpacity + 0.08, 0.9))
                appearance.backgroundColor = UIColor(baseColor).withAlphaComponent(opacity)
            } else if theme.usesGlassMaterials {
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(theme.glassBaseColor)
            } else {
                appearance.configureWithOpaqueBackground()
                appearance.backgroundEffect = nil
                appearance.backgroundColor = UIColor(theme.background)
            }
            applyTabItemAppearance(
                to: appearance,
                palette: palette
            )
            UITabBar.appearance().unselectedItemTintColor = UIColor(palette.inactive)
            appearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().tintColor = UIColor(palette.active)
        }
        #endif
    }
}

#if canImport(UIKit)
private extension RootTabView {
    func applyTabItemAppearance(
        to appearance: UITabBarAppearance,
        palette: AppTheme.TabBarPalette
    ) {
        appearance.stackedLayoutAppearance = makeTabItemAppearance(
            style: .stacked,
            palette: palette
        )
        appearance.inlineLayoutAppearance = makeTabItemAppearance(
            style: .inline,
            palette: palette
        )
        appearance.compactInlineLayoutAppearance = makeTabItemAppearance(
            style: .compactInline,
            palette: palette
        )
    }

    func makeTabItemAppearance(
        style: UITabBarItemAppearance.Style,
        palette: AppTheme.TabBarPalette
    ) -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance(style: style)
        itemAppearance.configureWithDefault(for: style)

        let activeColor = UIColor(palette.active)
        let inactiveColor = UIColor(palette.inactive)
        let disabledColor = UIColor(palette.disabled)
        let badgeBackground = UIColor(palette.badgeBackground)
        let badgeForeground = UIColor(palette.badgeForeground)

        configure(
            state: itemAppearance.normal,
            iconColor: inactiveColor,
            titleColor: inactiveColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configure(
            state: itemAppearance.selected,
            iconColor: activeColor,
            titleColor: activeColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configure(
            state: itemAppearance.focused,
            iconColor: activeColor,
            titleColor: activeColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configureDisabledState(
            itemAppearance.disabled,
            iconColor: disabledColor,
            badgeForeground: badgeForeground
        )

        return itemAppearance
    }

    func configure(
        state: UITabBarItemStateAppearance,
        iconColor: UIColor,
        titleColor: UIColor,
        badgeBackground: UIColor,
        badgeForeground: UIColor
    ) {
        state.iconColor = iconColor
        state.titleTextAttributes = [.foregroundColor: titleColor]
        state.badgeBackgroundColor = badgeBackground
        state.badgeTextAttributes = [.foregroundColor: badgeForeground]
    }

    func configureDisabledState(
        _ state: UITabBarItemStateAppearance,
        iconColor: UIColor,
        badgeForeground: UIColor
    ) {
        let disabledBadgeBackground = iconColor.withAlphaComponent(0.28)
        state.iconColor = iconColor
        state.titleTextAttributes = [.foregroundColor: iconColor]
        state.badgeBackgroundColor = disabledBadgeBackground
        state.badgeTextAttributes = [
            .foregroundColor: badgeForeground.withAlphaComponent(0.75)
        ]
    }
}
#endif

