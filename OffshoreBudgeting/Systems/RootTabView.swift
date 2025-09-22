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

    private enum Tab: Hashable {
        case home
        case income
        case cards
        case presets
        case settings
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            navigationContainer { HomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            navigationContainer { IncomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Income", systemImage: "calendar") }
                .tag(Tab.income)

            navigationContainer { CardsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Cards", systemImage: "creditcard") }
                .tag(Tab.cards)

            navigationContainer { PresetsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }
                .tag(Tab.presets)

            navigationContainer { SettingsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        // Give the tab chrome its own glass background so macOS matches iOS.
        .ub_chromeBackground(
            theme: themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration
        )
        .onAppear(perform: updateTabBarAppearance)
        .ub_onChange(of: themeManager.selectedTheme) {
            updateTabBarAppearance()
        }
        .ub_onChange(of: colorScheme) {
            updateTabBarAppearance()
        }
        .ub_onChange(of: platformCapabilities) {
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
            UITabBar.appearance().isTranslucent = theme.usesGlassMaterials

            applyAppearanceToVisibleTabBars(
                appearance: appearance,
                palette: palette,
                isTranslucent: theme.usesGlassMaterials
            )
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

    func applyAppearanceToVisibleTabBars(
        appearance: UITabBarAppearance,
        palette: AppTheme.TabBarPalette,
        isTranslucent: Bool
    ) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                tabBarControllers(in: window.rootViewController).forEach { controller in
                    let tabBar = controller.tabBar
                    tabBar.standardAppearance = appearance
                    tabBar.scrollEdgeAppearance = appearance
                    tabBar.tintColor = UIColor(palette.active)
                    tabBar.unselectedItemTintColor = UIColor(palette.inactive)
                    tabBar.isTranslucent = isTranslucent
                }
            }
    }

    func tabBarControllers(in root: UIViewController?) -> [UITabBarController] {
        guard let root else { return [] }

        var controllers: [UITabBarController] = []

        if let tabController = root as? UITabBarController {
            controllers.append(tabController)
        }

        controllers.append(contentsOf: root.children.flatMap { child in
            tabBarControllers(in: child)
        })

        if let presented = root.presentedViewController {
            controllers.append(contentsOf: tabBarControllers(in: presented))
        }

        return controllers
    }
}
#endif

