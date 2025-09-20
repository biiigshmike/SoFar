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

    #if os(macOS)
    @State private var macSelection: MacRootTab = .home
    @State private var homePath = NavigationPath()
    @State private var incomePath = NavigationPath()
    @State private var cardsPath = NavigationPath()
    @State private var presetsPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    #endif

    var body: some View {
        tabContainer
            .onAppear(perform: updateTabBarAppearance)
            .onChange(of: themeManager.selectedTheme) { _, _ in
                updateTabBarAppearance()
            }
            .onChange(of: platformCapabilities) { _, _ in
                updateTabBarAppearance()
            }
    }

    @ViewBuilder
    private var tabContainer: some View {
        #if os(macOS)
        if platformCapabilities.supportsOS26Translucency {
            modernMacRootTabView
        } else {
            standardTabInterface
        }
        #else
        standardTabInterface
        #endif
    }

    private var standardTabInterface: some View {
        TabView {
            navigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            navigationStack { IncomeView() }
                .tabItem { Label("Income", systemImage: "calendar") }

            navigationStack { CardsView() }
                .tabItem { Label("Cards", systemImage: "creditcard") }

            navigationStack { PresetsView() }
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }

            navigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .ub_chromeGlassBackground(
            baseColor: themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration
        )
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    @ViewBuilder
    private func navigationStack<Content: View>(
        path: Binding<NavigationPath>? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let path {
            NavigationStack(path: path) {
                content()
            }
            .ub_navigationGlassBackground(
                baseColor: themeManager.selectedTheme.glassBaseColor,
                configuration: themeManager.glassConfiguration
            )
        } else {
            NavigationStack {
                content()
            }
            .ub_navigationGlassBackground(
                baseColor: themeManager.selectedTheme.glassBaseColor,
                configuration: themeManager.glassConfiguration
            )
        }
    }

    #if os(macOS)
    private var modernMacRootTabView: some View {
        VStack(spacing: 0) {
            ZStack {
                macTabContent(.home, path: $homePath) { HomeView() }
                macTabContent(.income, path: $incomePath) { IncomeView() }
                macTabContent(.cards, path: $cardsPath) { CardsView() }
                macTabContent(.presets, path: $presetsPath) { PresetsView() }
                macTabContent(.settings, path: $settingsPath) { SettingsView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MacRootTabBar(
                selection: $macSelection,
                accent: themeManager.selectedTheme.resolvedTint,
                baseColor: themeManager.selectedTheme.glassBaseColor,
                configuration: themeManager.glassConfiguration
            )
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .ub_glassBackground(
            themeManager.selectedTheme.glassBaseColor,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    @ViewBuilder
    private func macTabContent<Content: View>(
        _ tab: MacRootTab,
        path: Binding<NavigationPath>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        navigationStack(path: path, content: content)
            .opacity(macSelection == tab ? 1 : 0)
            .allowsHitTesting(macSelection == tab)
            .zIndex(macSelection == tab ? 1 : 0)
    }
    #endif

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

#if os(macOS)
private enum MacRootTab: CaseIterable {
    case home
    case income
    case cards
    case presets
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .income: return "Income"
        case .cards: return "Cards"
        case .presets: return "Presets"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .income: return "calendar"
        case .cards: return "creditcard"
        case .presets: return "list.bullet.rectangle"
        case .settings: return "gear"
        }
    }
}

private struct MacRootTabBar: View {
    @Binding var selection: MacRootTab
    let accent: Color
    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration

    var body: some View {
        HStack(spacing: 12) {
            ForEach(MacRootTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(foregroundStyle(for: tab))
                    .padding(.horizontal, 2)
                }
                .buttonStyle(
                    MacLiquidTabButtonStyle(
                        isSelected: selection == tab,
                        accent: accent,
                        baseColor: baseColor,
                        configuration: configuration
                    )
                )
                .accessibilityIdentifier("root-tab-\(tab.systemImage)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .ub_chromeGlassBackground(
            baseColor: baseColor,
            configuration: configuration
        )
        .overlay(alignment: .top) {
            Divider()
                .blendMode(.overlay)
                .opacity(0.35)
        }
    }

    private func foregroundStyle(for tab: MacRootTab) -> LinearGradient {
        let active = selection == tab
        return LinearGradient(
            colors: [
                Color.white.opacity(active ? 0.98 : 0.78),
                accent.opacity(active ? 0.92 : 0.54)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct MacLiquidTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    let accent: Color
    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let active = isSelected || pressed
        let baseOpacity = self.configuration.liquid.tintOpacity
        let activeOpacity = min(baseOpacity + 0.28, 0.65)
        let inactiveOpacity = min(baseOpacity + 0.1, 0.32)
        let fillOpacity = active ? activeOpacity : inactiveOpacity

        return configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(baseColor.opacity(fillOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(active ? 0.38 : 0.18),
                                        accent.opacity(active ? 0.2 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.plusLighter)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                Color.white.opacity(active ? 0.3 : 0.18),
                                lineWidth: 1
                            )
                            .blendMode(.screen)
                    )
                    .shadow(
                        color: accent.opacity(active ? 0.32 : 0.16),
                        radius: active ? 14 : 8,
                        x: 0,
                        y: active ? 10 : 6
                    )
                    .compositingGroup()
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: pressed)
            .animation(.easeInOut(duration: 0.24), value: isSelected)
    }
}
#endif

