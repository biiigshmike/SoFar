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
        .onAppear(perform: updateTabBarAppearance)
        .onChange(of: themeManager.selectedTheme) { 
            updateTabBarAppearance()
        }
    }

    /// Ensures the tab bar always matches the current theme and hides the default top border.
    private func updateTabBarAppearance() {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(themeManager.selectedTheme.background)
            appearance.shadowColor = .clear
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().tintColor = UIColor(themeManager.selectedTheme.accent)
        }
        #endif
    }
}
