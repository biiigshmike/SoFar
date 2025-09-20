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

    var body: some View {
        TabView {
            navigationContainer { HomeView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Home", systemImage: "house") }

            navigationContainer { IncomeView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Income", systemImage: "calendar") }

            navigationContainer { CardsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Cards", systemImage: "creditcard") }

            navigationContainer { PresetsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            navigationContainer { SettingsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        // Give the tab chrome its own glass background so macOS matches iOS.
        .ub_chromeGlassBackground(
            baseColor: themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
        // Keep the page background as well.
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
        .onAppear(perform: updateTabBarAppearance)
        .onChange(of: themeManager.selectedTheme) { _ in
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
            if platformCapabilities.supportsOS26Translucency {
                appearance.configureWithTransparentBackground()
                let configuration = themeManager.glassConfiguration
                let blurStyle = configuration.glass.material.uiBlurEffectStyle
                appearance.backgroundEffect = UIBlurEffect(style: blurStyle)

                let baseColor = themeManager.selectedTheme.glassBaseColor
                let opacity = CGFloat(min(configuration.liquid.tintOpacity + 0.08, 0.9))
                appearance.backgroundColor = UIColor(baseColor).withAlphaComponent(opacity)

                let resolvedTint = UIColor(themeManager.selectedTheme.resolvedTint)
                applyOS26TabItemAppearance(
                    to: appearance,
                    tintColor: resolvedTint
                )
                UITabBar.appearance().unselectedItemTintColor = resolvedTint.withAlphaComponent(0.72)
            } else {
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(themeManager.selectedTheme.background)

                resetTabItemAppearance(on: appearance)
                UITabBar.appearance().unselectedItemTintColor = nil
            }
            appearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().tintColor = themeManager.selectedTheme.tint.map { UIColor($0) }
        }
        #endif
    }
}

#if canImport(UIKit)
private extension RootTabView {
    func applyOS26TabItemAppearance(
        to appearance: UITabBarAppearance,
        tintColor: UIColor
    ) {
        appearance.stackedLayoutAppearance = makeTabItemAppearance(
            style: .stacked,
            tintColor: tintColor
        )
        appearance.inlineLayoutAppearance = makeTabItemAppearance(
            style: .inline,
            tintColor: tintColor
        )
        appearance.compactInlineLayoutAppearance = makeTabItemAppearance(
            style: .compactInline,
            tintColor: tintColor
        )
    }

    func resetTabItemAppearance(on appearance: UITabBarAppearance) {
        appearance.stackedLayoutAppearance = makeDefaultTabItemAppearance(style: .stacked)
        appearance.inlineLayoutAppearance = makeDefaultTabItemAppearance(style: .inline)
        appearance.compactInlineLayoutAppearance = makeDefaultTabItemAppearance(style: .compactInline)
    }

    func makeTabItemAppearance(
        style: UITabBarItemAppearance.Style,
        tintColor: UIColor
    ) -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance(style: style)
        itemAppearance.configureWithDefault(for: style)

        configure(state: itemAppearance.normal, tintColor: tintColor, emphasis: 0.72)
        configure(state: itemAppearance.selected, tintColor: tintColor, emphasis: 1.0)
        configure(state: itemAppearance.focused, tintColor: tintColor, emphasis: 1.0)
        configureDisabledState(itemAppearance.disabled, tintColor: tintColor)

        return itemAppearance
    }

    func makeDefaultTabItemAppearance(style: UITabBarItemAppearance.Style) -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance(style: style)
        itemAppearance.configureWithDefault(for: style)
        return itemAppearance
    }

    func configure(state: UITabBarItemStateAppearance, tintColor: UIColor, emphasis: CGFloat) {
        let clampedAlpha = max(0.0, min(1.0, emphasis))
        let alphaColor = tintColor.withAlphaComponent(clampedAlpha)
        state.iconColor = alphaColor
        state.titleTextAttributes = [.foregroundColor: alphaColor]
        state.badgeBackgroundColor = tintColor
        state.badgeTextAttributes = [.foregroundColor: UIColor.white]
    }

    func configureDisabledState(_ state: UITabBarItemStateAppearance, tintColor: UIColor) {
        let disabledAlpha = tintColor.withAlphaComponent(0.32)
        state.iconColor = disabledAlpha
        state.titleTextAttributes = [.foregroundColor: disabledAlpha]
        state.badgeBackgroundColor = disabledAlpha
        state.badgeTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.9)]
    }
}
#endif

