//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//


import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var platformCapabilities

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { IncomeView() }
                .tabItem { Label("Income", systemImage: "calendar") }

            NavigationStack { CardsView() }
                .tabItem { Label("Cards", systemImage: "creditcard") }

            NavigationStack { PresetsView() }
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .ub_glassBackground(
            themeManager.selectedTheme.background,
            configuration: themeManager.selectedTheme.glassConfiguration,
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
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                appearance.backgroundColor = UIColor(themeManager.selectedTheme.background).withAlphaComponent(0.35)
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
