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

    /// Human readable name shown in pickers.
    var displayName: String {
        switch self {
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
    /// All custom themes specify a tint color.
    var tint: Color? {
        accent
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
        case .classic:
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
        }
    }

    /// Secondary background used for card interiors and icons.
    var secondaryBackground: Color {
        switch self {
        case .classic:
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
        }
    }

    /// Tertiary background for card shells.
    var tertiaryBackground: Color {
        switch self {
        case .classic:
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
        }
    }

    /// Preferred system color scheme for the theme.
    var colorScheme: ColorScheme {
        switch self {
        case .classic, .ocean, .sunrise, .blossom, .lavender, .mint:
            return .light
        case .midnight, .forest, .sunset, .nebula:
            return .dark
        }
    }

    /// Lists of themes grouped by their color scheme.
    static var lightThemes: [AppTheme] { [.classic, .ocean, .sunrise, .blossom, .lavender, .mint] }
    static var darkThemes: [AppTheme] { [.midnight, .forest, .sunset, .nebula] }
}

// MARK: - ThemeManager
/// Observable theme source of truth. Persists selection via `UserDefaults`
/// so the chosen themes survive app relaunches. Users can specify separate
/// themes for light and dark system appearances.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var lightTheme: AppTheme { didSet { if !isApplyingRemoteChange { save() } ; updateSelectedTheme() } }
    @Published var darkTheme: AppTheme { didSet { if !isApplyingRemoteChange { save() } ; updateSelectedTheme() } }
    @Published private(set) var selectedTheme: AppTheme { didSet { applyAppearance() } }

    private let lightStorageKey = "selectedLightTheme"
    private let darkStorageKey = "selectedDarkTheme"
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var isApplyingRemoteChange = false
    private var currentColorScheme: ColorScheme = .light

    /// Determines if theme syncing is enabled via Settings and iCloud.
    ///
    /// This property does not rely on any instance state, so it is defined as
    /// a `static` computed property. Doing so allows it to be accessed before
    /// the class has completed initialization, avoiding "self used before all
    /// stored properties are initialized" errors during `init`.
    private static var isSyncEnabled: Bool {
        let themeSync = UserDefaults.standard.object(forKey: AppSettingsKeys.syncAppTheme.rawValue) as? Bool ?? true
        let cloud = UserDefaults.standard.object(forKey: AppSettingsKeys.enableCloudSync.rawValue) as? Bool ?? true
        return themeSync && cloud
    }

    init() {
        let lightRaw: String?
        let darkRaw: String?
        if Self.isSyncEnabled {
            ubiquitousStore.synchronize()
            lightRaw = ubiquitousStore.string(forKey: lightStorageKey) ?? UserDefaults.standard.string(forKey: lightStorageKey)
            darkRaw = ubiquitousStore.string(forKey: darkStorageKey) ?? UserDefaults.standard.string(forKey: darkStorageKey)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(storeChanged(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitousStore
            )
        } else {
            lightRaw = UserDefaults.standard.string(forKey: lightStorageKey)
            darkRaw = UserDefaults.standard.string(forKey: darkStorageKey)
        }

        lightTheme = lightRaw.flatMap { AppTheme(rawValue: $0) } ?? .classic
        darkTheme = darkRaw.flatMap { AppTheme(rawValue: $0) } ?? .midnight
        selectedTheme = lightTheme
        applyAppearance()
    }

    private func save() {
        UserDefaults.standard.set(lightTheme.rawValue, forKey: lightStorageKey)
        UserDefaults.standard.set(darkTheme.rawValue, forKey: darkStorageKey)
        guard Self.isSyncEnabled else { return }
        ubiquitousStore.set(lightTheme.rawValue, forKey: lightStorageKey)
        ubiquitousStore.set(darkTheme.rawValue, forKey: darkStorageKey)
        ubiquitousStore.synchronize()
    }

    /// Updates the current theme based on the provided system color scheme.
    func refreshSystemAppearance(_ colorScheme: ColorScheme) {
        currentColorScheme = colorScheme
        updateSelectedTheme()
        // Ensure dynamic system colors within a theme resolve with the new scheme.
        objectWillChange.send()
    }

    /// Determines which theme should be active and applies it if needed.
    private func updateSelectedTheme() {
        let newTheme = currentColorScheme == .dark ? darkTheme : lightTheme
        if newTheme != selectedTheme {
            selectedTheme = newTheme
        }
    }

    /// Applies the appropriate system appearance for the selected theme.
    private func applyAppearance() {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = selectedTheme.colorScheme == .dark ? .dark : .light
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
        #elseif canImport(AppKit)
        let appearance = selectedTheme.colorScheme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        NSApp.appearance = appearance
        #endif
    }

    @objc private func storeChanged(_ note: Notification) {
        guard Self.isSyncEnabled else { return }
        ubiquitousStore.synchronize()
        let newLight = ubiquitousStore.string(forKey: lightStorageKey).flatMap { AppTheme(rawValue: $0) } ?? lightTheme
        let newDark = ubiquitousStore.string(forKey: darkStorageKey).flatMap { AppTheme(rawValue: $0) } ?? darkTheme
        if newLight != lightTheme || newDark != darkTheme {
            DispatchQueue.main.async {
                self.isApplyingRemoteChange = true
                self.lightTheme = newLight
                self.darkTheme = newDark
                self.isApplyingRemoteChange = false
                self.updateSelectedTheme()
            }
        }
    }
}
