import SwiftUI
import Combine
import Foundation
import UIKit

// MARK: - Cloud Sync Infrastructure
// This file's cloud-sync components require the iCloud Key-Value storage
// entitlement so they can interact with `NSUbiquitousKeyValueStore`.

/// An abstraction over `NSUbiquitousKeyValueStore`.
///
/// - Important: Using implementations backed by iCloud requires the iCloud
///   Key-Value storage entitlement to be enabled for the target.
protocol UbiquitousKeyValueStoring: AnyObject {
    @discardableResult
    func synchronize() -> Bool
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}

extension NSUbiquitousKeyValueStore: UbiquitousKeyValueStoring {}

protocol NotificationCentering: AnyObject {
    @discardableResult
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping @Sendable (Notification) -> Void) -> NSObjectProtocol
    func removeObserver(_ observer: Any)
    func post(name: NSNotification.Name, object obj: Any?)
}

/// Lightweight adapter that forwards `NotificationCentering` requests to a concrete
/// `NotificationCenter` instance. Using a dedicated type keeps the protocol usable
/// from Swift's concurrency domain checks without forcing the Foundation type to
/// adopt additional annotations.
final class NotificationCenterAdapter: NotificationCentering {
    static let shared = NotificationCenterAdapter()

    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    @discardableResult
    func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> NSObjectProtocol {
        return center.addObserver(forName: name, object: obj, queue: queue) { notification in
            block(notification)
        }
    }

    func removeObserver(_ observer: Any) {
        center.removeObserver(observer)
    }

    func post(name: NSNotification.Name, object obj: Any?) {
        center.post(name: name, object: obj)
    }
}

enum CloudSyncPreferences {
    static func disableAppThemeSync(in defaults: UserDefaults) {
        defaults.set(false, forKey: AppSettingsKeys.syncAppTheme.rawValue)
    }

    static func disableCardThemeSync(in defaults: UserDefaults) {
        defaults.set(false, forKey: AppSettingsKeys.syncCardThemes.rawValue)
    }
}

// MARK: - AppTheme
/// Centralized color palette for the application. Each case defines a
/// complete set of color used across the UI so that switching themes is
/// consistent everywhere.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    struct TabBarPalette {
        let active: Color
        let inactive: Color
        let disabled: Color
        let badgeBackground: Color
        let badgeForeground: Color
    }

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

    var id: String { rawValue }

    /// UI-facing list of selectable themes.
    static var selectableCases: [AppTheme] { allCases }

    /// Dynamic neutral accent that mirrors the system's black text in light mode
    /// and white text in dark mode without relying on an asset catalog color.
    private static var systemNeutralAccent: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 1.0)
                : UIColor(white: 0.0, alpha: 1.0)
        })
    }

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
        }
    }

    /// Accent color applied to interactive elements.
    var accent: Color {
        switch self {
        case .system:
            return AppTheme.systemNeutralAccent
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
        }
    }

    /// Optional tint color used for SwiftUI's `.tint` and `.accentColor` modifiers.
    ///
    /// All custom themes specify a tint color. The System theme intentionally
    /// returns platform-appropriate values so controls match native styling.
    /// On iOS and related platforms we rely on a dynamic neutral accent so the
    /// theme respects the project's light (black) and dark (white) accents
    /// instead of defaulting to the system blue.
    var tint: Color? {
        switch self {
        case .system:
            return AppTheme.systemNeutralAccent
        default:
            return accent
        }
    }

    /// Guaranteed accent value for glass effects. Falls back to `accent`
    /// when the theme opts into the system tint on iOS.
    var resolvedTint: Color { tint ?? accent }

    /// Preferred tint for toggle controls. Matches Apple's default green
    /// when following the system appearance so switches remain legible in
    /// both light and dark modes on newer OS releases.
    var toggleTint: Color {
        switch self {
        case .system:
            return Color(UIColor.systemGreen)
        default:
            return resolvedTint
        }
    }

    /// Secondary accent color derived from the primary accent.
    var secondaryAccent: Color {
        let uiColor = UIColor(accent)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s * 0.5), brightness: Double(min(b * 1.2, 1.0)))
    }

    /// Primary background color for views.
    var background: Color {
        switch self {
        case .system:
            return Color(UIColor.systemBackground)
        case .classic:
            return Color(UIColor.systemGroupedBackground)
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
        }
    }

    /// Secondary background used for card interiors and icons.
    var secondaryBackground: Color {
        switch self {
        case .system:
            return Color(UIColor.secondarySystemBackground)
        case .classic:
            return Color(UIColor.secondarySystemGroupedBackground)
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
        }
    }

    /// Tertiary background for card shells.
    var tertiaryBackground: Color {
        switch self {
        case .system:
            return Color(UIColor.tertiarySystemBackground)
        case .classic:
            return Color(UIColor.tertiarySystemGroupedBackground)
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
        }
    }

    /// Neutral foreground color suitable for primary labels within the theme.
    /// - Parameter colorScheme: The environment's resolved scheme. Used so that the
    ///   System theme can mirror the platform default of dark text in light mode and
    ///   light text in dark mode.
    func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .system:
            return colorScheme == .dark ? .white : .black
        default:
            return .primary
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
        }
    }

    /// Tunable translucent controls that define how OS 26 surfaces are rendered
    /// for the theme.
    var baseGlassConfiguration: GlassConfiguration {
        switch self {
        case .system:
            return AppTheme.systemGlassConfiguration(resolvedTint: resolvedTint)
        default:
            return .translucent(
                liquidAmount: GlassConfiguration.TranslucentDefaults.liquidAmount,
                glassAmount: GlassConfiguration.TranslucentDefaults.glassAmount,
                palette: glassPalette
            )
        }
    }

    /// Theme-aware base color used when rendering OS 26 translucent surfaces.
    var glassBaseColor: Color {
        let accentWash = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.45,
            brightnessMultiplier: 1.12,
            alpha: 1.0
        )

        let brightness = AppThemeColorUtilities.hsba(from: background)?.brightness ?? 0.65
        var blendAmount: Double
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

        switch self {
        case .system:
            return AppTheme.systemGlassBaseColor(resolvedTint: resolvedTint)
        default:
            return AppThemeColorUtilities.mix(background, accentWash, amount: blendAmount)
        }
    }

    /// Palette used when rendering OS 26 translucent surfaces.
    var glassPalette: GlassConfiguration.Palette {
        let accent: Color
        let shadow: Color
        let specular: Color
        let rim: Color

        switch self {
        case .system:
            let tintSaturation = AppThemeColorUtilities
                .hsba(from: resolvedTint)?.saturation ?? 0.0
            let tintBlend = tintSaturation.clamped(to: 0...1)

            let neutralAccent = Color(UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.70, green: 0.74, blue: 0.84, alpha: 1.0)
                } else {
                    return UIColor(red: 0.58, green: 0.62, blue: 0.72, alpha: 1.0)
                }
            })
            let neutralShadow = Color(UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1.0)
                } else {
                    return UIColor(red: 0.68, green: 0.72, blue: 0.80, alpha: 1.0)
                }
            })
            let neutralSpecular = Color(UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1.0)
                } else {
                    return UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
                }
            })
            let neutralRim = Color(UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(red: 0.82, green: 0.86, blue: 0.94, alpha: 1.0)
                } else {
                    return UIColor(red: 0.70, green: 0.74, blue: 0.84, alpha: 1.0)
                }
            })

            let accentTone = AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.10,
                brightnessMultiplier: 1.08,
                alpha: 1.0
            )
            let shadowTone = AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.10,
                brightnessMultiplier: 0.70,
                alpha: 1.0
            )
            let specularTone = AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.08,
                brightnessMultiplier: 1.30,
                alpha: 1.0
            )
            let rimTone = AppThemeColorUtilities.adjust(
                resolvedTint,
                saturationMultiplier: 0.08,
                brightnessMultiplier: 1.18,
                alpha: 1.0
            )

            accent = AppThemeColorUtilities.mix(neutralAccent, accentTone, amount: tintBlend)
            shadow = AppThemeColorUtilities.mix(neutralShadow, shadowTone, amount: tintBlend)
            specular = AppThemeColorUtilities.mix(neutralSpecular, specularTone, amount: tintBlend)
            rim = AppThemeColorUtilities.mix(neutralRim, rimTone, amount: tintBlend)
        default:
            accent = resolvedTint
            shadow = AppThemeColorUtilities.adjust(resolvedTint, saturationMultiplier: 1.05, brightnessMultiplier: 0.48, alpha: 1.0)
            specular = AppThemeColorUtilities.adjust(resolvedTint, saturationMultiplier: 0.62, brightnessMultiplier: 1.32, alpha: 1.0)
            rim = AppThemeColorUtilities.adjust(resolvedTint, saturationMultiplier: 0.68, brightnessMultiplier: 1.18, alpha: 1.0)
        }

        return GlassConfiguration.Palette(accent: accent, shadow: shadow, specular: specular, rim: rim)
    }

    /// Color palette used to render tab bar content across platforms.
    var tabBarPalette: TabBarPalette {
        let brightness = AppThemeColorUtilities.hsba(from: glassBaseColor)?.brightness
            ?? AppThemeColorUtilities.hsba(from: background)?.brightness
            ?? 0.65

        let baseColor: Color
        let inactiveAlpha: Double
        let disabledAlpha: Double

        if brightness < 0.45 {
            baseColor = .white
            inactiveAlpha = 0.94
            disabledAlpha = 0.42
        } else {
            baseColor = .black
            inactiveAlpha = 0.78
            disabledAlpha = 0.30
        }

        let active = resolvedTint
        let inactive = baseColor.opacity(inactiveAlpha)
        let disabled = baseColor.opacity(disabledAlpha)

        let badgeBackground = resolvedTint
        let badgeBrightness = AppThemeColorUtilities.hsba(from: resolvedTint)?.brightness ?? 0.85
        let badgeForeground: Color
        if badgeBrightness < 0.55 {
            badgeForeground = Color.white.opacity(0.96)
        } else {
            badgeForeground = Color.black.opacity(0.88)
        }

        return TabBarPalette(
            active: active,
            inactive: inactive,
            disabled: disabled,
            badgeBackground: badgeBackground,
            badgeForeground: badgeForeground
        )
    }

    /// Indicates whether the theme opts into the custom glass materials used
    /// throughout the interface. The System theme intentionally relies on the
    /// platform default backgrounds to closely mirror Apple's native apps.
    var usesGlassMaterials: Bool {
        switch self {
        case .system:
            return false
        default:
            return true
        }
    }
}

extension AppTheme {
    /// iOS/iPadOS System glass tuned brighter and more neutral.
    static func systemGlassConfiguration(resolvedTint: Color) -> GlassConfiguration {
        var configuration = AppTheme.GlassConfiguration.standard

        // Neutralize the glass surface like Apple's Settings background. Only blend
        // in the accent color when it is truly colorful so neutral black/white
        // accents do not muddy the grouped background.
        let tintSaturation = AppThemeColorUtilities
            .hsba(from: resolvedTint)?.saturation ?? 0.0
        let tintBlend = tintSaturation.clamped(to: 0...1)

        configuration.liquid.tintOpacity = 0.045
        configuration.liquid.saturation = 0.98
        configuration.liquid.brightness = 0.015
        configuration.liquid.contrast = 1.01
        configuration.liquid.bloom = 0.08

        let neutralShadow = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
            } else {
                return UIColor(red: 0.68, green: 0.72, blue: 0.80, alpha: 1.0)
            }
        })
        let neutralSpecular = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1.0)
            } else {
                return UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
            }
        })
        let neutralRim = Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.82, green: 0.86, blue: 0.94, alpha: 1.0)
            } else {
                return UIColor(red: 0.70, green: 0.74, blue: 0.84, alpha: 1.0)
            }
        })

        let shadowTone = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.10,
            brightnessMultiplier: 0.70,
            alpha: 1.0
        )
        let specularTone = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.08,
            brightnessMultiplier: 1.30,
            alpha: 1.0
        )
        let rimTone = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.08,
            brightnessMultiplier: 1.18,
            alpha: 1.0
        )

        configuration.glass.highlightOpacity = 0.36
        configuration.glass.highlightBlur = 26
        configuration.glass.shadowColor = AppThemeColorUtilities.mix(
            neutralShadow,
            shadowTone,
            amount: tintBlend
        )
        configuration.glass.shadowOpacity = 0.06
        configuration.glass.shadowBlur = 44
        configuration.glass.specularColor = AppThemeColorUtilities.mix(
            neutralSpecular,
            specularTone,
            amount: tintBlend
        )
        configuration.glass.specularOpacity = 0.12
        configuration.glass.specularWidth = 0.10
        configuration.glass.noiseOpacity = 0.018
        configuration.glass.rimColor = AppThemeColorUtilities.mix(
            neutralRim,
            rimTone,
            amount: tintBlend
        )
        configuration.glass.rimOpacity = 0.025
        configuration.glass.rimWidth = 0.78
        configuration.glass.rimBlur = 16
        configuration.glass.material = .thin

        return configuration
    }

    /// Near‑neutral base color for System theme (dynamic).
    static func systemGlassBaseColor(resolvedTint: Color) -> Color {
        let dynamicBase = UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0)
            } else {
                return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
            }
        }

        let baseColor = Color(dynamicBase)
        let tintSaturation = AppThemeColorUtilities
            .hsba(from: resolvedTint)?.saturation ?? 0.0
        let tintInfluence = tintSaturation.clamped(to: 0...1)

        guard tintInfluence > 0 else { return baseColor }

        let wash = AppThemeColorUtilities.adjust(
            resolvedTint,
            saturationMultiplier: 0.06,
            brightnessMultiplier: 1.06,
            alpha: 1.0
        )

        return AppThemeColorUtilities.mix(
            baseColor,
            wash,
            amount: 0.02 * tintInfluence
        )
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

                #if os(iOS) || os(tvOS)
                @available(iOS 15.0, macCatalyst 15.0, tvOS 15.0, *)
                var shapeStyle: AnyShapeStyle {
                    switch self {
                    case .ultraThin: return AnyShapeStyle(.ultraThinMaterial)
                    case .thin: return AnyShapeStyle(.thinMaterial)
                    case .regular: return AnyShapeStyle(.regularMaterial)
                    case .thick: return AnyShapeStyle(.thickMaterial)
                    case .ultraThick: return AnyShapeStyle(.ultraThickMaterial)
                    }
                }
                #endif

                var uiBlurEffectStyle: UIBlurEffect.Style {
                    switch self {
                    case .ultraThin: return .systemUltraThinMaterial
                    case .thin: return .systemThinMaterial
                    case .regular: return .systemMaterial
                    case .thick: return .systemThickMaterial
                    case .ultraThick: return .systemChromeMaterial
                    }
                }
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
    enum TranslucentDefaults {
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
            tintOpacity: 0.14,
            saturation: 1.04,
            brightness: 0.02,
            contrast: 1.02,
            bloom: 0.12
        ),
        glass: .init(
            highlightColor: .white,
            highlightOpacity: 0.32,
            highlightBlur: 36,
            shadowColor: Color(.sRGB, red: 0.10, green: 0.12, blue: 0.18, opacity: 1.0),
            shadowOpacity: 0.16,
            shadowBlur: 40,
            specularColor: .white,
            specularOpacity: 0.22,
            specularWidth: 0.08,
            noiseOpacity: 0.028,
            rimColor: .white,
            rimOpacity: 0.06,
            rimWidth: 1.0,
            rimBlur: 14,
            material: .ultraThin
        )
    )

    static func translucent(
        liquidAmount: Double,
        glassAmount: Double,
        palette: AppTheme.GlassConfiguration.Palette = TranslucentDefaults.palette
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
            case ..<0.33: material = .ultraThin
            case ..<0.66: material = .thin
            default:      material = .regular
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
        let platformColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return RGBA(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }

    static func hsba(from color: Color) -> HSBA? {
        let platformColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard platformColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return nil }
        return HSBA(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), alpha: Double(alpha))
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

        return Self.color(from: components)
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
@MainActor
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme = .system { didSet { if !isApplyingRemoteChange { save() }; applyAppearance() } }

    private let storageKey = "selectedTheme"
    private static let legacyLiquidGlassIdentifier = "tahoe"
    private let ubiquitousStoreFactory: () -> UbiquitousKeyValueStoring
    private var cachedUbiquitousStore: UbiquitousKeyValueStoring?
    private let userDefaults: UserDefaults
    private let defaultCloudStatusProviderFactory: () -> CloudAvailabilityProviding
    private var pendingInjectedCloudStatusProvider: CloudAvailabilityProviding?
    private var cloudStatusProvider: CloudAvailabilityProviding?
    private let notificationCenter: NotificationCentering
    private var availabilityCancellable: AnyCancellable?
    private var hasRequestedCloudAvailabilityCheck = false
    private var ubiquitousObserver: NSObjectProtocol?
    private var isApplyingRemoteChange = false

    init(
        userDefaults: UserDefaults = .standard,
        ubiquitousStoreFactory: @escaping () -> UbiquitousKeyValueStoring = { NSUbiquitousKeyValueStore.default },
        cloudStatusProvider: CloudAvailabilityProviding? = nil,
        notificationCenter: NotificationCentering = NotificationCenterAdapter.shared
    ) {
        self.userDefaults = userDefaults
        self.ubiquitousStoreFactory = ubiquitousStoreFactory
        self.pendingInjectedCloudStatusProvider = cloudStatusProvider
        self.defaultCloudStatusProviderFactory = { CloudAccountStatusProvider.shared }
        self.notificationCenter = notificationCenter

        let initialTheme: AppTheme
        if Self.isThemeSyncEnabled(in: userDefaults) {
            let provider = resolveCloudStatusProvider()
            if Self.isCloudAvailable(from: provider) {
                let store = instantiateUbiquitousStore()
                _ = store.synchronize()
                let raw = store.string(forKey: storageKey) ?? userDefaults.string(forKey: storageKey)
                initialTheme = Self.resolveTheme(from: raw)
            } else {
                let raw = userDefaults.string(forKey: storageKey)
                initialTheme = Self.resolveTheme(from: raw)
            }
        } else {
            let raw = userDefaults.string(forKey: storageKey)
            initialTheme = Self.resolveTheme(from: raw)
        }
        selectedTheme = initialTheme

        if shouldUseICloud {
            startObservingUbiquitousStoreIfNeeded()
        }
        applyAppearance()
    }

    @MainActor
    deinit {
        availabilityCancellable?.cancel()
        stopObservingUbiquitousStore()
    }

    var glassConfiguration: AppTheme.GlassConfiguration {
        return selectedTheme.baseGlassConfiguration
    }

    private func save() {
        userDefaults.set(selectedTheme.rawValue, forKey: storageKey)
        guard let store = ubiquitousStoreIfAvailable() else { return }

        guard store.synchronize() else {
            handleICloudSynchronizationFailure()
            return
        }

        store.set(selectedTheme.rawValue, forKey: storageKey)

        guard store.synchronize() else {
            handleICloudSynchronizationFailure()
            return
        }
    }

    func refreshSystemAppearance(_ colorScheme: ColorScheme) {
        guard selectedTheme.colorScheme == nil else { return }
        applyAppearance()
        objectWillChange.send()
    }

    private func applyAppearance() {
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
    }

    private static func resolveTheme(from raw: String?) -> AppTheme {
        if let raw, raw == legacyLiquidGlassIdentifier {
            return .system
        }
        return raw.flatMap { AppTheme(rawValue: $0) } ?? .system
    }

    private static func isThemeSyncEnabled(in defaults: UserDefaults) -> Bool {
        let themeSync = defaults.object(forKey: AppSettingsKeys.syncAppTheme.rawValue) as? Bool ?? false
        let cloud = defaults.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? false
        return themeSync && cloud
    }

    private static func isCloudAvailable(from provider: CloudAvailabilityProviding) -> Bool {
        guard let available = provider.isCloudAccountAvailable else { return false }
        return available
    }

    private func resolveCloudStatusProvider() -> CloudAvailabilityProviding {
        if let provider = cloudStatusProvider {
            scheduleAvailabilityCheckIfNeeded(for: provider)
            return provider
        }

        let provider = pendingInjectedCloudStatusProvider ?? defaultCloudStatusProviderFactory()
        pendingInjectedCloudStatusProvider = nil
        cloudStatusProvider = provider

        availabilityCancellable?.cancel()
        availabilityCancellable = provider.availabilityPublisher
            .sink { [weak self] availability in
                self?.handleCloudAvailabilityChange(availability)
            }

        scheduleAvailabilityCheckIfNeeded(for: provider)
        return provider
    }

    private func scheduleAvailabilityCheckIfNeeded(for provider: CloudAvailabilityProviding) {
        guard !hasRequestedCloudAvailabilityCheck else { return }
        hasRequestedCloudAvailabilityCheck = true
        Task { @MainActor in
            _ = await provider.resolveAvailability(forceRefresh: false)
        }
    }

    private var shouldUseICloud: Bool {
        guard Self.isThemeSyncEnabled(in: userDefaults) else { return false }
        let provider = resolveCloudStatusProvider()
        return Self.isCloudAvailable(from: provider)
    }

    private func handleCloudAvailabilityChange(_ availability: CloudAccountStatusProvider.Availability) {
        switch availability {
        case .available:
            guard Self.isThemeSyncEnabled(in: userDefaults) else { return }
            startObservingUbiquitousStoreIfNeeded()
            loadThemeFromCloud()
        case .unavailable:
            stopObservingUbiquitousStore()
            CloudSyncPreferences.disableAppThemeSync(in: userDefaults)
        case .unknown:
            break
        }
    }

    private func loadThemeFromCloud() {
        guard let store = ubiquitousStoreIfAvailable() else { return }

        guard store.synchronize() else {
            handleICloudSynchronizationFailure()
            applyThemeFromUserDefaultsIfNeeded()
            return
        }

        let raw = store.string(forKey: storageKey) ?? userDefaults.string(forKey: storageKey)
        applyThemeIfNeeded(from: raw)
    }

    private func applyThemeFromUserDefaultsIfNeeded() {
        let raw = userDefaults.string(forKey: storageKey)
        applyThemeIfNeeded(from: raw)
    }

    private func applyThemeIfNeeded(from raw: String?) {
        let newTheme = Self.resolveTheme(from: raw)
        guard newTheme != selectedTheme else { return }
        DispatchQueue.main.async {
            self.isApplyingRemoteChange = true
            self.selectedTheme = newTheme
            self.isApplyingRemoteChange = false
        }
    }

    private func startObservingUbiquitousStoreIfNeeded() {
        guard ubiquitousObserver == nil else { return }
        guard let store = ubiquitousStoreIfAvailable() else { return }
        ubiquitousObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store as AnyObject,
            queue: nil
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleUbiquitousStoreChange(note)
            }
        }
    }

    private func stopObservingUbiquitousStore() {
        if let observer = ubiquitousObserver {
            notificationCenter.removeObserver(observer)
            ubiquitousObserver = nil
        }
    }

    private func handleUbiquitousStoreChange(_ note: Notification) {
        guard shouldUseICloud else { return }
        loadThemeFromCloud()
    }

    private func handleICloudSynchronizationFailure() {
        stopObservingUbiquitousStore()
        CloudSyncPreferences.disableAppThemeSync(in: userDefaults)
        let provider = resolveCloudStatusProvider()
        provider.requestAccountStatusCheck(force: true)
        if AppLog.isVerbose {
            AppLog.iCloud.info("ThemeManager fell back to UserDefaults after iCloud synchronize() failed")
        }
}

    private func instantiateUbiquitousStore() -> UbiquitousKeyValueStoring {
        if let store = cachedUbiquitousStore {
            return store
        }
        let store = ubiquitousStoreFactory()
        cachedUbiquitousStore = store
        return store
    }

    private func ubiquitousStoreIfAvailable() -> UbiquitousKeyValueStoring? {
        guard shouldUseICloud else { return nil }
        return instantiateUbiquitousStore()
    }
}
