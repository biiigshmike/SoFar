//
//  RootTabView.swift
//  so-far
//
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import ObjectiveC
#endif

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var platformCapabilities
    @Environment(\.colorScheme) private var colorScheme

    private enum Tab: Hashable {
        case home
        case income
        case cards
        case presets
        case settings
    }

    @State private var selectedTab: Tab = .home
#if canImport(UIKit)
    @State private var lastTabBarAppearanceSignature: TabBarAppearanceSignature?
    @State private var isUpdatingTabBarAppearance = false
#endif

    var body: some View {
        TabView(selection: $selectedTab) {
            navigationContainer { HomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            navigationContainer { IncomeView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Income", systemImage: "calendar") }
                .tag(Tab.income)

            navigationContainer { CardsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Cards", systemImage: "creditcard") }
                .tag(Tab.cards)

            navigationContainer { PresetsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Presets", systemImage: "list.bullet.rectangle") }
                .tag(Tab.presets)

            navigationContainer { SettingsView() }
                .ub_navigationBackground(
                    theme: themeManager.selectedTheme,
                    configuration: themeManager.glassConfiguration
                )
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        // Give the tab chrome its own glass background so macOS matches iOS.
        .ub_chromeBackground(
            theme: themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration
        )
        .onAppear(perform: updateTabBarAppearance)
        .ub_onChange(of: themeManager.selectedTheme) {
            updateTabBarAppearance()
        }
        .ub_onChange(of: colorScheme) {
            updateTabBarAppearance()
        }
        .ub_onChange(of: platformCapabilities) {
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
    @MainActor private func updateTabBarAppearance() {
        #if canImport(UIKit)
        let theme = themeManager.selectedTheme
        let palette = theme.tabBarPalette
        let configuration = themeManager.glassConfiguration
        let capabilities = platformCapabilities
        let currentColorScheme = colorScheme

        let newSignature = TabBarAppearanceSignature.make(
            theme: theme,
            colorScheme: currentColorScheme,
            capabilities: capabilities,
            configuration: configuration,
            palette: palette,
            resolveColor: { color, scheme in
                resolveUIColor(color, for: scheme)
            }
        )

        if newSignature == lastTabBarAppearanceSignature {
            return
        }

        guard !isUpdatingTabBarAppearance else {
            return
        }

        isUpdatingTabBarAppearance = true
        defer {
            lastTabBarAppearanceSignature = newSignature
            isUpdatingTabBarAppearance = false
        }

        let appearance = UITabBarAppearance()

        if theme.usesGlassMaterials && capabilities.supportsOS26Translucency {
            appearance.configureWithTransparentBackground()
            let blurStyle = configuration.glass.material.uiBlurEffectStyle
            appearance.backgroundEffect = UIBlurEffect(style: blurStyle)

            let baseColor = resolveUIColor(theme.glassBaseColor, for: currentColorScheme)
            let opacity = CGFloat(min(configuration.liquid.tintOpacity + 0.08, 0.9))
            appearance.backgroundColor = baseColor.withAlphaComponent(opacity)
        } else if theme.usesGlassMaterials {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = resolveUIColor(theme.glassBaseColor, for: currentColorScheme)
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = resolveUIColor(theme.background, for: currentColorScheme)
        }

        applyTabItemAppearance(
            to: appearance,
            palette: palette,
            colorScheme: currentColorScheme
        )

        let inactiveTint = resolveUIColor(palette.inactive, for: currentColorScheme)
        let activeTint = resolveUIColor(palette.active, for: currentColorScheme)

        appearance.shadowColor = .clear

        let globalAppearance = UITabBar.appearance()
        globalAppearance.unselectedItemTintColor = inactiveTint
        globalAppearance.standardAppearance = copyAppearance(appearance)
        globalAppearance.scrollEdgeAppearance = copyAppearance(appearance)
        globalAppearance.tintColor = activeTint
        globalAppearance.isTranslucent = theme.usesGlassMaterials

        applyAppearanceToVisibleTabBars(
            appearance: appearance,
            palette: palette,
            isTranslucent: theme.usesGlassMaterials,
            colorScheme: currentColorScheme,
            signature: newSignature
        )
        #endif
    }
}

#if canImport(UIKit)
private extension RootTabView {
    func applyTabItemAppearance(
        to appearance: UITabBarAppearance,
        palette: AppTheme.TabBarPalette,
        colorScheme: ColorScheme
    ) {
        appearance.stackedLayoutAppearance = makeTabItemAppearance(
            style: .stacked,
            palette: palette,
            colorScheme: colorScheme
        )
        appearance.inlineLayoutAppearance = makeTabItemAppearance(
            style: .inline,
            palette: palette,
            colorScheme: colorScheme
        )
        appearance.compactInlineLayoutAppearance = makeTabItemAppearance(
            style: .compactInline,
            palette: palette,
            colorScheme: colorScheme
        )
    }

    func makeTabItemAppearance(
        style: UITabBarItemAppearance.Style,
        palette: AppTheme.TabBarPalette,
        colorScheme: ColorScheme
    ) -> UITabBarItemAppearance {
        let itemAppearance = UITabBarItemAppearance(style: style)
        itemAppearance.configureWithDefault(for: style)

        let activeColor = resolveUIColor(palette.active, for: colorScheme)
        let inactiveColor = resolveUIColor(palette.inactive, for: colorScheme)
        let disabledColor = resolveUIColor(palette.disabled, for: colorScheme)
        let badgeBackground = resolveUIColor(palette.badgeBackground, for: colorScheme)
        let badgeForeground = resolveUIColor(palette.badgeForeground, for: colorScheme)

        configure(
            state: itemAppearance.normal,
            iconColor: inactiveColor,
            titleColor: inactiveColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configure(
            state: itemAppearance.selected,
            iconColor: activeColor,
            titleColor: activeColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configure(
            state: itemAppearance.focused,
            iconColor: activeColor,
            titleColor: activeColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
        configureDisabledState(
            itemAppearance.disabled,
            iconColor: disabledColor,
            badgeForeground: badgeForeground
        )

        return itemAppearance
    }

    func configure(
        state: UITabBarItemStateAppearance,
        iconColor: UIColor,
        titleColor: UIColor,
        badgeBackground: UIColor,
        badgeForeground: UIColor
    ) {
        state.iconColor = iconColor
        state.titleTextAttributes = [.foregroundColor: titleColor]
        state.badgeBackgroundColor = badgeBackground
        state.badgeTextAttributes = [.foregroundColor: badgeForeground]
    }

    func configureDisabledState(
        _ state: UITabBarItemStateAppearance,
        iconColor: UIColor,
        badgeForeground: UIColor
    ) {
        let disabledBadgeBackground = iconColor.withAlphaComponent(0.28)
        state.iconColor = iconColor
        state.titleTextAttributes = [.foregroundColor: iconColor]
        state.badgeBackgroundColor = disabledBadgeBackground
        state.badgeTextAttributes = [
            .foregroundColor: badgeForeground.withAlphaComponent(0.75)
        ]
    }

    @MainActor func applyAppearanceToVisibleTabBars(
        appearance: UITabBarAppearance,
        palette: AppTheme.TabBarPalette,
        isTranslucent: Bool,
        colorScheme: ColorScheme,
        signature: TabBarAppearanceSignature
    ) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                tabBarControllers(in: window.rootViewController).forEach { controller in
                    let tabBar = controller.tabBar
                    guard tabBar.ub_cachedAppearanceSignature != signature else {
                        return
                    }

                    let standardAppearance = copyAppearance(appearance)
                    let scrollEdgeAppearance = copyAppearance(appearance)
                    tabBar.standardAppearance = standardAppearance
                    tabBar.scrollEdgeAppearance = scrollEdgeAppearance
                    tabBar.tintColor = resolveUIColor(palette.active, for: colorScheme)
                    tabBar.unselectedItemTintColor = resolveUIColor(palette.inactive, for: colorScheme)
                    tabBar.isTranslucent = isTranslucent
                    tabBar.ub_cachedAppearanceSignature = signature
                }
            }
    }

    func resolveUIColor(_ color: Color, for colorScheme: ColorScheme) -> UIColor {
        let uiColor = UIColor(color)

        let style: UIUserInterfaceStyle
        switch colorScheme {
        case .dark:
            style = .dark
        case .light:
            style = .light
        @unknown default:
            style = .unspecified
        }

        let traitCollection = UITraitCollection(userInterfaceStyle: style)
        return uiColor.resolvedColor(with: traitCollection)
    }

    func copyAppearance(_ appearance: UITabBarAppearance) -> UITabBarAppearance {
        appearance.copy() as! UITabBarAppearance
    }

    func tabBarControllers(in root: UIViewController?) -> [UITabBarController] {
        guard let root else { return [] }

        var controllers: [UITabBarController] = []

        if let tabController = root as? UITabBarController {
            controllers.append(tabController)
        }

        controllers.append(contentsOf: root.children.flatMap { child in
            tabBarControllers(in: child)
        })

        if let presented = root.presentedViewController {
            controllers.append(contentsOf: tabBarControllers(in: presented))
        }

        return controllers
    }
}

private final class TabBarAppearanceSignatureBox: NSObject {
    let signature: TabBarAppearanceSignature

    init(signature: TabBarAppearanceSignature) {
        self.signature = signature
    }
}

private extension UITabBar {
    private enum AssociatedKeys {
        static var appearanceSignature: UInt8 = 0
    }

    var ub_cachedAppearanceSignature: TabBarAppearanceSignature? {
        get {
            guard let box = objc_getAssociatedObject(self, &AssociatedKeys.appearanceSignature) as? TabBarAppearanceSignatureBox else {
                return nil
            }

            return box.signature
        }
        set {
            if let signature = newValue {
                let box = TabBarAppearanceSignatureBox(signature: signature)
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.appearanceSignature,
                    box,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            } else {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.appearanceSignature,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }
}

private struct ColorComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.red = Double(red)
            self.green = Double(green)
            self.blue = Double(blue)
            self.alpha = Double(alpha)
            return
        }

        if let components = uiColor.cgColor.components {
            switch components.count {
            case 4:
                red = components[0]
                green = components[1]
                blue = components[2]
                alpha = components[3]
            case 3:
                red = components[0]
                green = components[1]
                blue = components[2]
                alpha = uiColor.cgColor.alpha
            case 2:
                red = components[0]
                green = components[0]
                blue = components[0]
                alpha = components[1]
            case 1:
                red = components[0]
                green = components[0]
                blue = components[0]
                alpha = uiColor.cgColor.alpha
            default:
                red = 0
                green = 0
                blue = 0
                alpha = 0
            }
        }

        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.alpha = Double(alpha)
    }
}

private struct TabBarAppearanceSignature: Equatable {
    struct PaletteSignature: Equatable {
        let active: ColorComponents
        let inactive: ColorComponents
        let disabled: ColorComponents
        let badgeBackground: ColorComponents
        let badgeForeground: ColorComponents
    }

    struct BackgroundSignature: Equatable {
        let isTranslucent: Bool
        let supportsTranslucency: Bool
        let blurStyleRawValue: Int?
        let backgroundColor: ColorComponents
    }

    let themeID: String
    let colorScheme: ColorScheme
    let capabilities: PlatformCapabilities
    let background: BackgroundSignature
    let palette: PaletteSignature

    static func make(
        theme: AppTheme,
        colorScheme: ColorScheme,
        capabilities: PlatformCapabilities,
        configuration: AppTheme.GlassConfiguration,
        palette: AppTheme.TabBarPalette,
        resolveColor: (Color, ColorScheme) -> UIColor
    ) -> TabBarAppearanceSignature {
        let activeColor = ColorComponents(uiColor: resolveColor(palette.active, colorScheme))
        let inactiveColor = ColorComponents(uiColor: resolveColor(palette.inactive, colorScheme))
        let disabledColor = ColorComponents(uiColor: resolveColor(palette.disabled, colorScheme))
        let badgeBackground = ColorComponents(uiColor: resolveColor(palette.badgeBackground, colorScheme))
        let badgeForeground = ColorComponents(uiColor: resolveColor(palette.badgeForeground, colorScheme))

        let usesGlassMaterials = theme.usesGlassMaterials
        let supportsTranslucency = capabilities.supportsOS26Translucency
        let blurStyleRawValue: Int?

        let backgroundUIColor: UIColor
        if usesGlassMaterials && supportsTranslucency {
            blurStyleRawValue = configuration.glass.material.uiBlurEffectStyle.rawValue
            let baseColor = resolveColor(theme.glassBaseColor, colorScheme)
            let opacity = CGFloat(min(configuration.liquid.tintOpacity + 0.08, 0.9))
            backgroundUIColor = baseColor.withAlphaComponent(opacity)
        } else if usesGlassMaterials {
            blurStyleRawValue = nil
            backgroundUIColor = resolveColor(theme.glassBaseColor, colorScheme)
        } else {
            blurStyleRawValue = nil
            backgroundUIColor = resolveColor(theme.background, colorScheme)
        }

        let paletteSignature = PaletteSignature(
            active: activeColor,
            inactive: inactiveColor,
            disabled: disabledColor,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )

        let backgroundSignature = BackgroundSignature(
            isTranslucent: usesGlassMaterials,
            supportsTranslucency: supportsTranslucency,
            blurStyleRawValue: blurStyleRawValue,
            backgroundColor: ColorComponents(uiColor: backgroundUIColor)
        )

        return TabBarAppearanceSignature(
            themeID: theme.id,
            colorScheme: colorScheme,
            capabilities: capabilities,
            background: backgroundSignature,
            palette: paletteSignature
        )
    }
}
#endif

