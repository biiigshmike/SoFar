//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//


import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager

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
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
        .onAppear(perform: updateAppearance)
        .onChange(of: themeManager.selectedTheme) {
            updateAppearance()
        }
    }

    /// Applies the selected theme to both the tab bar and navigation bar so the
    /// chrome consistently reflects user preferences.
    private func updateAppearance() {
        #if canImport(UIKit)
        // ---- Tab Bar ----
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(themeManager.selectedTheme.background)
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(themeManager.selectedTheme.accent)

        // ---- Navigation Bar ----
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(themeManager.selectedTheme.background)
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.selectedTheme.accent)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.selectedTheme.accent)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(themeManager.selectedTheme.accent)
        #endif
    }
}
