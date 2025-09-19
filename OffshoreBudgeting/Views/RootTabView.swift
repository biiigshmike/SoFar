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
            NavigationStack { HomeView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { IncomeView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Income", systemImage: "calendar") }

            NavigationStack { CardsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Cards", systemImage: "creditcard") }

            NavigationStack { PresetsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            NavigationStack { SettingsView() }
                .ub_navigationGlassBackground(
                    baseColor: themeManager.selectedTheme.glassBaseColor,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
        .onAppear(perform: updateTabBarAppearance)
        .onChange(of: themeManager.selectedTheme) { _, _ in
            updateTabBarAppearance()
        }
        .onChange(of: platformCapabilities) { _, _ in
            updateTabBarAppearance()
        }
    }

    /// Ensures the tab bar always matches the current theme and hides the default top border.
    private func updateTabBarAppearance() {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            let appearance = UITabBarAppearance()
            if platformCapabilities.supportsLiquidGlass {
                appearance.configureWithTransparentBackground()
                let configuration = themeManager.glassConfiguration
                let blurStyle = configuration.glass.material.uiBlurEffectStyle
                appearance.backgroundEffect = UIBlurEffect(style: blurStyle)

                let baseColor = themeManager.selectedTheme.glassBaseColor
                let opacity = CGFloat(min(configuration.liquid.tintOpacity + 0.08, 0.9))
                appearance.backgroundColor = UIColor(baseColor).withAlphaComponent(opacity)
            } else {
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(themeManager.selectedTheme.background)
            }
            appearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().tintColor = themeManager.selectedTheme.tint.map { UIColor($0) }
        }
        #endif
    }
}
