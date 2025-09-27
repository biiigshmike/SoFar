//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    #if os(macOS)
    @Environment(\.platformCapabilities) private var platformCapabilities
    #endif

    enum Tab: Hashable, CaseIterable {
        case home
        case income
        case cards
        case presets
        case settings
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        #if os(macOS)
        macBody
        #else
        tabViewBody
        #endif
    }

    private var tabViewBody: some View {
        TabView(selection: $selectedTab) {
            tabViewItem(for: .home)
            tabViewItem(for: .income)
            tabViewItem(for: .cards)
            tabViewItem(for: .presets)
            tabViewItem(for: .settings)
        }
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
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                #if os(iOS)
                .navigationViewStyle(StackNavigationViewStyle())
                #endif
        }
    }

    #if os(macOS)
    private var macBody: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationStack {
                    decoratedTabContent(for: selectedTab)
                }
            } else {
                NavigationView {
                    decoratedTabContent(for: selectedTab)
                }
            }
        }
        .toolbar {
            macToolbar
        }
        .modifier(
            MacToolbarBackgroundModifier(
                theme: themeManager.selectedTheme,
                supportsTranslucency: platformCapabilities.supportsOS26Translucency
            )
        )
    }

    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            MacRootTabBar(
                selectedTab: $selectedTab,
                palette: themeManager.selectedTheme.tabBarPalette
            )
            .frame(maxWidth: .infinity)
        }
    }
    #endif
}

#if os(macOS)
private struct MacToolbarBackgroundModifier: ViewModifier {
    let theme: AppTheme
    let supportsTranslucency: Bool

    func body(content: Content) -> some View {
        if supportsTranslucency {
            content
        } else {
            if #available(macOS 13.0, *) {
                content
                    .toolbarBackground(.visible, for: .windowToolbar)
                    .toolbarBackground(theme.background, for: .windowToolbar)
            } else {
                content
            }
        }
    }
}
#endif

#if os(macOS)
private struct MacRootTabBar: View {
    @Environment(\.platformCapabilities) private var platformCapabilities

    private let tabs: [RootTabView.Tab]
    @Binding private var selectedTab: RootTabView.Tab
    private let palette: AppTheme.TabBarPalette

    init(
        tabs: [RootTabView.Tab] = RootTabView.Tab.allCases,
        selectedTab: Binding<RootTabView.Tab>,
        palette: AppTheme.TabBarPalette
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.palette = palette
    }

    private var metrics: TranslucentButtonStyle.Metrics {
        TranslucentButtonStyle.Metrics.macRootTab(for: platformCapabilities)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                MacTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    palette: palette
                ) {
                    selectedTab = tab
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.height)
    }
}

private struct MacTabButton: View {
    @Environment(\.platformCapabilities) private var platformCapabilities

    let tab: RootTabView.Tab
    let isSelected: Bool
    let palette: AppTheme.TabBarPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MacTabLabel(tab: tab, isSelected: isSelected, palette: palette)
        }
        .buttonStyle(
            TranslucentButtonStyle(
                tint: palette.active,
                metrics: .macRootTab(for: platformCapabilities)
            )
        )
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}

private struct MacTabLabel: View {
    let tab: RootTabView.Tab
    let isSelected: Bool
    let palette: AppTheme.TabBarPalette

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.systemImage)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: 20, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? palette.active : palette.inactive)
    }
}
#endif

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
