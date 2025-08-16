//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//


import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView().screenBackground() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { IncomeView().screenBackground() }
                .tabItem { Label("Income", systemImage: "calendar") }

            NavigationStack { CardsView().screenBackground() }
                .tabItem { Label("Cards", systemImage: "creditcard") }

            NavigationStack { PresetsView().screenBackground() }
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            NavigationStack { SettingsView().screenBackground() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .screenBackground()
    }
}
