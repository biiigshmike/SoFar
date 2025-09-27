//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

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
                palette: themeManager.selectedTheme.tabBarPalette,
                platformCapabilities: platformCapabilities
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
    private let tabs: [RootTabView.Tab]
    @Binding private var selectedTab: RootTabView.Tab
    private let palette: AppTheme.TabBarPalette
    private let platformCapabilities: PlatformCapabilities
    @Namespace private var glassNamespace

    init(
        tabs: [RootTabView.Tab] = RootTabView.Tab.allCases,
        selectedTab: Binding<RootTabView.Tab>,
        palette: AppTheme.TabBarPalette,
        platformCapabilities: PlatformCapabilities = .fallback
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.palette = palette
        self.platformCapabilities = platformCapabilities
    }

    private var metrics: TranslucentButtonStyle.Metrics {
        TranslucentButtonStyle.Metrics.macRootTab(for: platformCapabilities)
    }

    private var buttonMinWidth: CGFloat {
        // Resolve optional height; fall back to the diameter implied by the corner radius.
        let resolvedHeight = metrics.height ?? (metrics.cornerRadius * 2)
        let contentWidth = max(longestTabTitleWidth, resolvedHeight * 0.55)
        let paddedWidth = contentWidth + (metrics.horizontalPadding * 2)
        return ceil(paddedWidth)
    }

    private var buttonContentMinWidth: CGFloat {
        max(buttonMinWidth - (metrics.horizontalPadding * 2), 0)
    }

    private var longestTabTitleWidth: CGFloat {
        #if canImport(AppKit)
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return tabs
            .map { tab in
                ceil((tab.title as NSString).size(withAttributes: [.font: font]).width)
            }
            .max() ?? 0
        #else
        return 0
        #endif
    }

    var body: some View {
        Group {
            if platformCapabilities.supportsOS26Translucency {
                if #available(macOS 26.0, *) {
                    glassTabBar
                } else {
                    legacyTabBar
                }
            } else {
                legacyTabBar
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.height)
    }

    private var legacyTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                legacyTabButton(for: tab)
            }
        }
    }

    @available(macOS 26.0, *)
    private var glassTabBar: some View {
        HStack(spacing: glassSpacing) {
            ForEach(tabs, id: \.self) { tab in
                glassTabButton(for: tab)
            }
        }
    }

    private var glassSpacing: CGFloat {
        max(metrics.horizontalPadding / 2, 8)
    }

    private func legacyTabButton(for tab: RootTabView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            MacTabLabel(tab: tab, isSelected: selectedTab == tab)
        }
        .buttonStyle(
            TranslucentButtonStyle(
                tint: palette.active,
                metrics: metrics
            )
        )
        .frame(minWidth: buttonMinWidth, maxWidth: .infinity)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(accessibilityTraits(for: tab))
    }

    @available(macOS 26.0, *)
    private func glassTabButton(for tab: RootTabView.Tab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            MacTabLabel(tab: tab, isSelected: isSelected)
                .padding(.horizontal, metrics.horizontalPadding)
                .frame(minWidth: buttonContentMinWidth, maxWidth: .infinity)
                .frame(height: metrics.height)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .frame(minWidth: buttonMinWidth, maxWidth: .infinity)
        .glassEffectUnion(id: tab, namespace: glassNamespace)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(accessibilityTraits(for: tab))
    }

    private func accessibilityTraits(for tab: RootTabView.Tab) -> AccessibilityTraits {
        selectedTab == tab ? .isSelected : AccessibilityTraits()
    }
}

private struct MacTabLabel: View {
    let tab: RootTabView.Tab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tab.systemImage)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: 20, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if isSelected {
                selectionIndicator
            }
        }
    }

    private var selectionIndicator: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .frame(height: 3)
            .padding(.horizontal, 10)
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
