import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - AppTheme
/// Centralized color palette for the application. Each case defines a
/// complete set of color used across the UI so that switching themes is
/// consistent everywhere.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    /// Follows the system appearance and accent colors.
    case system
    case classic
    case midnight
    case forest
    case sunset
    case nebula
    case ocean
    case sunrise
    case blossom
    case lavender
    case mint
    case liquidGlass = "tahoe"

    var id: String { rawValue }

    /// Human readable name shown in pickers.
    var displayName: String {
        switch self {
        case .system: return "System"
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        case .nebula: return "Nebula"
        case .ocean: return "Ocean"
        case .sunrise: return "Sunrise"
        case .blossom: return "Blossom"
        case .lavender: return "Lavender"
        case .mint: return "Mint"
        case .liquidGlass: return "Liquid Glass"
        }
    }

    /// Accent color applied to interactive elements.
    var accent: Color {
        switch self {
        case .system: return .accentColor
        case .classic: return .blue
        case .midnight: return .purple
        case .forest: return .green
        case .sunset: return .orange
        case .nebula: return .pink
        case .ocean: return Color(red: 0.0, green: 0.6, blue: 0.7)
        case .sunrise: return .yellow
        case .blossom: return Color(red: 1.0, green: 0.4, blue: 0.7)
        case .lavender: return .purple
        case .mint: return Color(red: 0.0, green: 0.7, blue: 0.5)
        case .liquidGlass: return Color(red: 0.27, green: 0.58, blue: 0.98)
        }
    }

    /// Optional tint color used for SwiftUI's `.tint` and `.accentColor` modifiers.
    ///
    /// All custom themes specify a tint color. The System theme intentionally
    /// returns platform-appropriate values so controls match native styling.
    var tint: Color? {
        switch self {
        case .system:
            #if os(macOS)
            // Mimic the default iOS link color rather than adopting the user's
            // chosen macOS accent color to keep cross-platform cohesion.
            return Color(nsColor: .systemBlue)
            #else
            return nil
            #endif
        default:
            return accent
        }
    }

    /// Guaranteed accent value for glass effects. Falls back to `accent`
    /// when the theme opts into the system tint on iOS.
    var resolvedTint: Color { tint ?? accent }

    /// Secondary accent color derived from the primary accent. Used for
    /// distinguishing secondary actions (e.g., Edit vs. Delete) while still
    /// remaining harmonious with the selected theme.
    var secondaryAccent: Color {
        #if canImport(UIKit)
        let uiColor = UIColor(accent)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.5), brightness: Double(min(b * 1.2, 1.0)))
        #elseif canImport(AppKit)
        let nsColor = NSColor(accent)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        converted.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.5), brightness: Double(min(b * 1.2, 1.0)))
        #else
        return accent
        #endif
    }

    /// Primary background color for views.
    var background: Color {
        switch self {
        case .system, .classic:
            #if canImport(UIKit)
            // Use the grouped background so form rows stand out against the
            // surrounding view, matching the native Settings appearance.
            return Color(UIColor.systemGroupedBackground)
            #elseif canImport(AppKit)
            if #available(macOS 11.0, *) {
                return Color(nsColor: NSColor.windowBackgroundColor)
            } else {
                return Color.white
            }
            #else
            return Color.white
            #endif
        case .midnight:
            return Color.black
        case .forest:
            return Color(red: 0.05, green: 0.14, blue: 0.10)
        case .sunset:
            return Color(red: 0.12, green: 0.05, blue: 0.02)
        case .nebula:
            return Color(red: 0.05, green: 0.02, blue: 0.10)
        case .ocean:
            return Color(red: 0.90, green: 0.95, blue: 1.0)
        case .sunrise:
            return Color(red: 1.0, green: 0.95, blue: 0.90)
        case .blossom:
            return Color(red: 1.0, green: 0.95, blue: 0.98)
        case .lavender:
            return Color(red: 0.95, green: 0.94, blue: 1.0)
        case .mint:
            return Color(red: 0.93, green: 1.0, blue: 0.94)
        case .liquidGlass:
            return Color(red: 0.98, green: 0.99, blue: 1.0)
        }
    }

    /// Secondary background used for card interiors and icons.
    var secondaryBackground: Color {
        switch self {
        case .system, .classic:
            #if canImport(UIKit)
            // Provide a subtle card color that contrasts with the grouped
            // sheet background on iOS.
            return Color(UIColor.secondarySystemGroupedBackground)
            #elseif canImport(AppKit)
            if #available(macOS 11.0, *) {
                return Color(nsColor: NSColor.controlBackgroundColor)
            } else {
                return Color.gray.opacity(0.1)
            }
            #else
            return Color.gray.opacity(0.1)
            #endif
        case .midnight:
            return Color(red: 0.15, green: 0.15, blue: 0.18)
        case .forest:
            return Color(red: 0.09, green: 0.20, blue: 0.15)
        case .sunset:
            return Color(red: 0.18, green: 0.09, blue: 0.04)
        case .nebula:
            return Color(red: 0.10, green: 0.04, blue: 0.18)
        case .ocean:
            return Color(red: 0.80, green: 0.90, blue: 0.95)
        case .sunrise:
            return Color(red: 1.0, green: 0.90, blue: 0.85)
        case .blossom:
            return Color(red: 1.0, green: 0.90, blue: 0.95)
        case .lavender:
            return Color(red: 0.90, green: 0.88, blue: 0.98)
        case .mint:
            return Color(red: 0.88, green: 0.98, blue: 0.90)
        case .liquidGlass:
            return Color(red: 0.94, green: 0.97, blue: 1.0)
        }
    }

    /// Tertiary background for card shells.
    var tertiaryBackground: Color {
        switch self {
        case .system, .classic:
            #if canImport(UIKit)
            return Color(UIColor.tertiarySystemGroupedBackground)
            #elseif canImport(AppKit)
            if #available(macOS 11.0, *) {
                return Color(nsColor: NSColor.controlBackgroundColor)
            } else {
                return Color.gray.opacity(0.15)
            }
            #else
            return Color.gray.opacity(0.15)
            #endif
        case .midnight:
            return Color(red: 0.12, green: 0.12, blue: 0.15)
        case .forest:
            return Color(red: 0.07, green: 0.16, blue: 0.12)
        case .sunset:
            return Color(red: 0.15, green: 0.08, blue: 0.03)
        case .nebula:
            return Color(red: 0.08, green: 0.03, blue: 0.15)
        case .ocean:
            return Color(red: 0.70, green: 0.85, blue: 0.95)
        case .sunrise:
            return Color(red: 0.98, green: 0.85, blue: 0.80)
        case .blossom:
            return Color(red: 0.98, green: 0.85, blue: 0.92)
        case .lavender:
            return Color(red: 0.85, green: 0.83, blue: 0.95)
        case .mint:
            return Color(red: 0.83, green: 0.95, blue: 0.86)
        case .liquidGlass:
            return Color(red: 0.88, green: 0.94, blue: 1.0)
        }
    }

    /// Preferred system color scheme for the theme. A value of `nil` means the
    /// theme should follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .classic, .ocean, .sunrise, .blossom, .lavender, .mint:
            return .light
        case .midnight, .forest, .sunset, .nebula:
            return .dark
        case .liquidGlass:
            return .light
        }
    }

    /// Tunable Liquid Glass controls that define how translucent surfaces are
    /// rendered for the theme.
    var baseGlassConfiguration: GlassConfiguration {
        switch self {
        case .liquidGlass:
            return .liquidGlass(
                liquidAmount: GlassConfiguration.LiquidGlassDefaults.liquidAmount,
                glassAmount: GlassConfiguration.LiquidGlassDefaults.glassAmount,
                palette: glassPalette
            )
        default:
            return .liquidGlass(
                liquidAmount: GlassConfiguration.LiquidGlassDefaults.liquidAmount,
                glassAmount: GlassConfiguration.LiquidGlassDefaults.glassAmount,
                palette: glassPalette
            )
        }
    }

    /// Theme-aware base color used when rendering Liquid Glass surfaces. The
    /// value blends the theme's background with a softened version of the
    /// accent tint so that every palette gains a hint of the selected hue.
    var glassBaseColor: Color {
        #if canImport(UIKit) || canImport(AppKit)
        let accentWash = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.45,
            brightnessMultiplier: 1.12,
            alpha: 1.0
        )

        let brightness = AppThemeColorUtilities.hsba(from: background)?.brightness ?? 0.65
        let blendAmount: Double
        switch brightness {
        case ..<0.35:
            blendAmount = 0.58
        case ..<0.55:
            blendAmount = 0.42
        case ..<0.75:
            blendAmount = 0.32
        default:
            blendAmount = 0.24
        }

        return AppThemeColorUtilities.mix(background, accentWash, amount: blendAmount)
        #else
        return background
        #endif
    }

    /// Palette describing the vibrant accent colors applied to highlights,
    /// shadows, and rims when rendering Liquid Glass.
    var glassPalette: GlassConfiguration.Palette {
        #if canImport(UIKit) || canImport(AppKit)
        return GlassConfiguration.Palette(
            accent: resolvedTint,
            shadow: AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 1.05,
                brightnessMultiplier: 0.48,
                alpha: 1.0
            ),
            specular: AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.62,
                brightnessMultiplier: 1.32,
                alpha: 1.0
            ),
            rim: AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.68,
                brightnessMultiplier: 1.18,
                alpha: 1.0
            )
        )
        #else
        return GlassConfiguration.Palette(
            accent: resolvedTint,
            shadow: Color(red: 0.30, green: 0.49, blue: 0.82),
            specular: Color(red: 0.60, green: 0.82, blue: 1.0),
            rim: Color(red: 0.55, green: 0.78, blue: 1.0)
        )
        #endif
    }
}

// MARK: - AppTheme.GlassConfiguration

extension AppTheme {
    struct GlassConfiguration {
        struct Palette {
            var accent: Color
            var shadow: Color
            var specular: Color
            var rim: Color
        }

        struct LiquidSettings {
            var tintOpacity: Double
            var saturation: Double
            var brightness: Double
            var contrast: Double
            var bloom: Double
        }

        struct GlassSettings {
            enum MaterialStyle {
                case ultraThin
                case thin
                case regular
                case thick
                case ultraThick

                #if os(iOS) || os(tvOS) || os(macOS)
                @available(iOS 15.0, macOS 13.0, tvOS 15.0, *)
                var shapeStyle: AnyShapeStyle {
                    switch self {
                    case .ultraThin:
                        return AnyShapeStyle(.ultraThinMaterial)
                    case .thin:
                        return AnyShapeStyle(.thinMaterial)
                    case .regular:
                        return AnyShapeStyle(.regularMaterial)
                    case .thick:
                        return AnyShapeStyle(.thickMaterial)
                    case .ultraThick:
                        return AnyShapeStyle(.ultraThickMaterial)
                    }
                }
                #endif

                #if canImport(UIKit)
                var uiBlurEffectStyle: UIBlurEffect.Style {
                    switch self {
                    case .ultraThin:
                        return .systemUltraThinMaterial
                    case .thin:
                        return .systemThinMaterial
                    case .regular:
                        return .systemMaterial
                    case .thick:
                        return .systemThickMaterial
                    case .ultraThick:
                        return .systemChromeMaterial
                    }
                }
                #endif

                #if canImport(AppKit)
                @available(macOS 13.0, *)
                var visualEffectMaterial: NSVisualEffectView.Material {
                    switch self {
                    case .ultraThin:
                        return .headerView
                    case .thin:
                        return .titlebar
                    case .regular:
                        return .menu
                    case .thick:
                        return .windowBackground
                    case .ultraThick:
                        return .hudWindow
                    }
                }
                #endif
            }

            var highlightColor: Color
            var highlightOpacity: Double
            var highlightBlur: Double

            var shadowColor: Color
            var shadowOpacity: Double
            var shadowBlur: Double

            var specularColor: Color
            var specularOpacity: Double
            var specularWidth: Double

            var noiseOpacity: Double

            var rimColor: Color
            var rimOpacity: Double
            var rimWidth: Double
            var rimBlur: Double

            var material: MaterialStyle
        }

        var liquid: LiquidSettings
        var glass: GlassSettings
    }
}

extension AppTheme.GlassConfiguration {
    enum LiquidGlassDefaults {
        static let liquidAmount: Double = 0.7
        static let glassAmount: Double = 0.68
        static let palette = AppTheme.GlassConfiguration.Palette(
            accent: Color(red: 0.27, green: 0.58, blue: 0.98),
            shadow: Color(red: 0.30, green: 0.49, blue: 0.82),
            specular: Color(red: 0.60, green: 0.82, blue: 1.0),
            rim: Color(red: 0.55, green: 0.78, blue: 1.0)
        )
    }

    static let standard = AppTheme.GlassConfiguration(
        liquid: .init(
            tintOpacity: 0.22,
            saturation: 1.0,
            brightness: 0.0,
            contrast: 1.0,
            bloom: 0.0
        ),
        glass: .init(
            highlightColor: .white,
            highlightOpacity: 0.18,
            highlightBlur: 14,
            shadowColor: .black,
            shadowOpacity: 0.12,
            shadowBlur: 18,
            specularColor: .white,
            specularOpacity: 0.10,
            specularWidth: 0.06,
            noiseOpacity: 0.035,
            rimColor: .white,
            rimOpacity: 0.0,
            rimWidth: 1.0,
            rimBlur: 6,
            material: .ultraThin
        )
    )

    static func liquidGlass(
        liquidAmount: Double,
        glassAmount: Double,
        palette: AppTheme.GlassConfiguration.Palette = LiquidGlassDefaults.palette
    ) -> AppTheme.GlassConfiguration {
        let clampedLiquid = liquidAmount.clamped(to: 0...1)
        let clampedGlass = glassAmount.clamped(to: 0...1)

        let tintOpacity = Double.lerp(0.12, 0.44, clampedLiquid)
        let saturation = Double.lerp(1.0, 1.28, clampedLiquid)
        let brightness = Double.lerp(0.0, 0.05, clampedLiquid)
        let contrast = Double.lerp(0.98, 1.08, clampedLiquid)
        let bloom = Double.lerp(0.0, 0.22, clampedLiquid)

        let highlightOpacity = Double.lerp(0.2, 0.44, clampedGlass)
        let highlightBlur = Double.lerp(22, 60, clampedGlass)
        let shadowOpacity = Double.lerp(0.08, 0.26, clampedGlass)
        let shadowBlur = Double.lerp(20, 64, clampedGlass)
        let specularOpacity = Double.lerp(0.14, 0.46, clampedGlass)
        let specularWidth = Double.lerp(0.04, 0.12, clampedGlass)
        let noiseOpacity = Double.lerp(0.02, 0.06, clampedGlass)
        let rimOpacity = Double.lerp(0.0, 0.16, clampedGlass)
        let rimWidth = Double.lerp(0.8, 1.4, clampedGlass)
        let rimBlur = Double.lerp(8, 20, clampedGlass)

        let material: AppTheme.GlassConfiguration.GlassSettings.MaterialStyle
        switch clampedGlass {
        case ..<0.33:
            material = .ultraThin
        case ..<0.66:
            material = .thin
        default:
            material = .regular
        }

        return AppTheme.GlassConfiguration(
            liquid: .init(
                tintOpacity: tintOpacity,
                saturation: saturation,
                brightness: brightness,
                contrast: contrast,
                bloom: bloom
            ),
            glass: .init(
                highlightColor: Color.white,
                highlightOpacity: highlightOpacity,
                highlightBlur: highlightBlur,
                shadowColor: palette.shadow,
                shadowOpacity: shadowOpacity,
                shadowBlur: shadowBlur,
                specularColor: palette.specular,
                specularOpacity: specularOpacity,
                specularWidth: specularWidth,
                noiseOpacity: noiseOpacity,
                rimColor: palette.rim,
                rimOpacity: rimOpacity,
                rimWidth: rimWidth,
                rimBlur: rimBlur,
                material: material
            )
        )
    }
}

// MARK: - Color Utilities

fileprivate enum AppThemeColorUtilities {
    struct RGBA {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double
    }

    struct HSBA {
        var hue: Double
        var saturation: Double
        var brightness: Double
        var alpha: Double
    }

    static func rgba(from color: Color) -> RGBA? {
        #if canImport(UIKit)
        let platformColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return RGBA(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        #elseif canImport(AppKit)
        let platformColor = NSColor(color)
        let converted = platformColor.usingColorSpace(.deviceRGB) ?? platformColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return RGBA(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        #else
        return nil
        #endif
    }

    static func hsba(from color: Color) -> HSBA? {
        #if canImport(UIKit)
        let platformColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard platformColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return nil }
        return HSBA(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), alpha: Double(alpha))
        #elseif canImport(AppKit)
        let platformColor = NSColor(color)
        let converted = platformColor.usingColorSpace(.deviceRGB) ?? platformColor
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard converted.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return nil }
        return HSBA(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), alpha: Double(alpha))
        #else
        return nil
        #endif
    }

    static func color(from rgba: RGBA) -> Color {
        Color(
            red: rgba.red.clamped(to: 0...1),
            green: rgba.green.clamped(to: 0...1),
            blue: rgba.blue.clamped(to: 0...1),
            opacity: rgba.alpha.clamped(to: 0...1)
        )
    }

    static func color(from hsba: HSBA) -> Color {
        let normalizedHue = ((hsba.hue.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
        return Color(
            hue: normalizedHue,
            saturation: hsba.saturation.clamped(to: 0...1),
            brightness: hsba.brightness.clamped(to: 0...1),
            opacity: hsba.alpha.clamped(to: 0...1)
        )
    }

    static func mix(_ lhs: Color, _ rhs: Color, amount: Double) -> Color {
        let t = amount.clamped(to: 0...1)
        guard
            let left = rgba(from: lhs),
            let right = rgba(from: rhs)
        else { return lhs }

        let mixed = RGBA(
            red: left.red + (right.red - left.red) * t,
            green: left.green + (right.green - left.green) * t,
            blue: left.blue + (right.blue - left.blue) * t,
            alpha: left.alpha + (right.alpha - left.alpha) * t
        )

        return color(from: mixed)
    }

    static func adjust(
        _ color: Color,
        saturationMultiplier: Double,
        brightnessMultiplier: Double,
        alpha: Double? = nil
    ) -> Color {
        guard var components = hsba(from: color) else {
            if let alpha { return color.opacity(alpha) }
            return color
        }

        components.saturation = (components.saturation * saturationMultiplier).clamped(to: 0...1)
        components.brightness = (components.brightness * brightnessMultiplier).clamped(to: 0...1)
        if let alpha { components.alpha = alpha.clamped(to: 0...1) }

        return color(from: components)
    }
}

fileprivate extension Double {
    static func lerp(_ min: Double, _ max: Double, _ amount: Double) -> Double {
        min + (max - min) * amount
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        if self < range.lowerBound { return range.lowerBound }
        if self > range.upperBound { return range.upperBound }
        return self
    }
}

// MARK: - ThemeManager
/// Observable theme source of truth. Persists selection via `UserDefaults`
/// so the chosen theme survives app relaunches. Syncs with iCloud when
/// enabled in settings.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme { didSet { if !isApplyingRemoteChange { save() }; applyAppearance() } }
    @Published var liquidGlassCustomization: LiquidGlassCustomization { didSet { saveLiquidGlassCustomization() } }

    private let storageKey = "selectedTheme"
    private static let liquidGlassStorageKey = "liquidGlassCustomization"
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var isApplyingRemoteChange = false

    /// Determines if theme syncing is enabled via Settings and iCloud.
    ///
    /// This property does not rely on any instance state, so it is defined as
    /// a `static` computed property. Doing so allows it to be accessed before
    /// the class has completed initialization, avoiding "self used before all
    /// stored properties are initialized" errors during `init`.
    private static var isSyncEnabled: Bool {
        let themeSync = UserDefaults.standard.object(forKey: AppSettingsKeys.syncAppTheme.rawValue) as? Bool ?? false
        let cloud = UserDefaults.standard.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? false
        return themeSync && cloud
    }

    init() {
        liquidGlassCustomization = Self.loadLiquidGlassCustomization()

        let raw: String?
        if Self.isSyncEnabled {
            ubiquitousStore.synchronize()
            raw = ubiquitousStore.string(forKey: storageKey) ??
                UserDefaults.standard.string(forKey: storageKey)
        } else {
            raw = UserDefaults.standard.string(forKey: storageKey)
        }

        selectedTheme = raw.flatMap { AppTheme(rawValue: $0) } ?? .system

        if Self.isSyncEnabled {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(storeChanged(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitousStore
            )
        }

        applyAppearance()
    }

    var glassConfiguration: AppTheme.GlassConfiguration {
        AppTheme.GlassConfiguration.liquidGlass(
            liquidAmount: liquidGlassCustomization.liquidAmount,
            glassAmount: liquidGlassCustomization.glassDepth,
            palette: selectedTheme.glassPalette
        )
    }

    func updateLiquidGlass(liquidAmount: Double? = nil, glassDepth: Double? = nil) {
        let newLiquid = liquidAmount.map { $0.clamped(to: 0...1) } ?? liquidGlassCustomization.liquidAmount
        let newGlass = glassDepth.map { $0.clamped(to: 0...1) } ?? liquidGlassCustomization.glassDepth

        if newLiquid != liquidGlassCustomization.liquidAmount || newGlass != liquidGlassCustomization.glassDepth {
            liquidGlassCustomization = LiquidGlassCustomization(liquidAmount: newLiquid, glassDepth: newGlass)
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        guard Self.isSyncEnabled else { return }
        ubiquitousStore.set(selectedTheme.rawValue, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private func saveLiquidGlassCustomization() {
        guard let data = try? JSONEncoder().encode(liquidGlassCustomization) else { return }
        UserDefaults.standard.set(data, forKey: Self.liquidGlassStorageKey)
    }

    /// Updates the current theme based on the provided system color scheme.
    /// When using the System theme, this ensures views update as the user
    /// toggles light/dark mode.
    func refreshSystemAppearance(_ colorScheme: ColorScheme) {
        guard selectedTheme.colorScheme == nil else { return }
        applyAppearance()
        objectWillChange.send()
    }

    /// Applies the appropriate system appearance for the selected theme.
    private func applyAppearance() {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle
        if let scheme = selectedTheme.colorScheme {
            style = scheme == .dark ? .dark : .light
        } else {
            style = .unspecified
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
        #elseif canImport(AppKit)
        if let scheme = selectedTheme.colorScheme {
            let appearance = scheme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            NSApp.appearance = appearance
        } else {
            NSApp.appearance = nil
        }
        #endif
    }

    @objc private func storeChanged(_ note: Notification) {
        guard Self.isSyncEnabled else { return }
        ubiquitousStore.synchronize()
        let newTheme = ubiquitousStore.string(forKey: storageKey).flatMap { AppTheme(rawValue: $0) } ?? selectedTheme
        if newTheme != selectedTheme {
            DispatchQueue.main.async {
                self.isApplyingRemoteChange = true
                self.selectedTheme = newTheme
                self.isApplyingRemoteChange = false
            }
        }
    }
}

extension ThemeManager {
    struct LiquidGlassCustomization: Codable {
        var liquidAmount: Double
        var glassDepth: Double

        static let `default` = LiquidGlassCustomization(
            liquidAmount: AppTheme.GlassConfiguration.LiquidGlassDefaults.liquidAmount,
            glassDepth: AppTheme.GlassConfiguration.LiquidGlassDefaults.glassAmount
        )
    }

    private static func loadLiquidGlassCustomization() -> LiquidGlassCustomization {
        guard
            let data = UserDefaults.standard.data(forKey: Self.liquidGlassStorageKey),
            let customization = try? JSONDecoder().decode(LiquidGlassCustomization.self, from: data)
        else {
            return .default
        }

        return LiquidGlassCustomization(
            liquidAmount: customization.liquidAmount.clamped(to: 0...1),
            glassDepth: customization.glassDepth.clamped(to: 0...1)
        )
    }
}
