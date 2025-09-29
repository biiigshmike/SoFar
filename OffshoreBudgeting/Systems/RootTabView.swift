//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    enum Tab: Hashable, CaseIterable {
        case home
        case income
        case cards
        case presets
        case settings
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        tabViewBody
    }

    private var tabViewBody: some View {
        TabView(selection: $selectedTab) {
            tabViewItem(for: .home)
            tabViewItem(for: .income)
            tabViewItem(for: .cards)
            tabViewItem(for: .presets)
            tabViewItem(for: .settings)
        }
        .ub_chromeBackground(
            theme: themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration
        )
    }

    @ViewBuilder
    private func tabViewItem(for tab: Tab) -> some View {
        navigationContainer {
            decoratedTabContent(for: tab)
        }
        .tabItem { Label(tab.title, systemImage: tab.systemImage) }
        .tag(tab)
    }

    @ViewBuilder
    private func decoratedTabContent(for tab: Tab) -> some View {
        tabContent(for: tab)
            .ub_navigationBackground(
                theme: themeManager.selectedTheme,
                configuration: themeManager.glassConfiguration
            )
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .income:
            IncomeView()
        case .cards:
            CardsView()
        case .presets:
            PresetsView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

private extension RootTabView.Tab {
    var title: String {
        switch self {
        case .home:
            return "Home"
        case .income:
            return "Income"
        case .cards:
            return "Cards"
        case .presets:
            return "Presets"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .income:
            return "calendar"
        case .cards:
            return "creditcard"
        case .presets:
            return "list.bullet.rectangle"
        case .settings:
            return "gear"
        }
    }
}
