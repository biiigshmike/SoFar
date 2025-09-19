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
    case tahoe

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
        case .tahoe: return "Tahoe"
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
        case .tahoe: return Color(red: 0.20, green: 0.56, blue: 0.98)
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
        case .tahoe:
            return Color(red: 0.07, green: 0.13, blue: 0.22)
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
        case .tahoe:
            return Color(red: 0.12, green: 0.21, blue: 0.30)
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
        case .tahoe:
            return Color(red: 0.16, green: 0.27, blue: 0.36)
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
        case .midnight, .forest, .sunset, .nebula, .tahoe:
            return .dark
        }
    }

    /// Tunable Liquid Glass controls that define how translucent surfaces are
    /// rendered for the theme.
    var glassConfiguration: GlassConfiguration {
        switch self {
        case .tahoe:
            return .tahoe
        default:
            return .standard
        }
    }
}

// MARK: - AppTheme.GlassConfiguration

extension AppTheme {
    struct GlassConfiguration {
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

    static let tahoe = AppTheme.GlassConfiguration(
        liquid: .init(
            tintOpacity: 0.36,
            saturation: 1.28,
            brightness: 0.06,
            contrast: 1.08,
            bloom: 0.22
        ),
        glass: .init(
            highlightColor: Color(red: 0.80, green: 0.94, blue: 1.0),
            highlightOpacity: 0.48,
            highlightBlur: 32,
            shadowColor: Color(red: 0.00, green: 0.16, blue: 0.32),
            shadowOpacity: 0.42,
            shadowBlur: 36,
            specularColor: Color(red: 0.66, green: 0.82, blue: 1.0),
            specularOpacity: 0.58,
            specularWidth: 0.035,
            noiseOpacity: 0.12,
            rimColor: Color(red: 0.54, green: 0.78, blue: 1.0),
            rimOpacity: 0.28,
            rimWidth: 2.4,
            rimBlur: 18,
            material: .thin
        )
    )
}

// MARK: - ThemeManager
/// Observable theme source of truth. Persists selection via `UserDefaults`
/// so the chosen theme survives app relaunches. Syncs with iCloud when
/// enabled in settings.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme { didSet { if !isApplyingRemoteChange { save() }; applyAppearance() } }

    private let storageKey = "selectedTheme"
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

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        guard Self.isSyncEnabled else { return }
        ubiquitousStore.set(selectedTheme.rawValue, forKey: storageKey)
        ubiquitousStore.synchronize()
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
