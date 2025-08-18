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
            return Color(UIColor.systemBackground)
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
            return Color(UIColor.secondarySystemBackground)
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
            return Color(UIColor.tertiarySystemBackground)
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
}

// MARK: - ThemeManager
/// Observable theme source of truth. Persists selection via `UserDefaults`
/// so the chosen theme survives app relaunches.
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            if !isApplyingRemoteChange { save() }
        }
    }

    private let storageKey = "selectedTheme"
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var isApplyingRemoteChange = false
    private var defaultsObserver: NSObjectProtocol?
    private var cloudObserver: NSObjectProtocol?

    /// Determines if theme syncing is enabled via Settings and iCloud.
    private var isSyncEnabled: Bool {
        let themeSync = UserDefaults.standard.bool(forKey: AppSettingsKeys.syncAppTheme.rawValue)
        let cloud = UserDefaults.standard.bool(forKey: AppSettingsKeys.enableCloudSync.rawValue)
        return themeSync && cloud
    }

    init() {
        // Start with a sensible default, then configure based on sync state.
        selectedTheme = .classic
        configureSync()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureSync()
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    /// Configure theme syncing based on the latest user defaults.
    private func configureSync() {
        if isSyncEnabled {
            ubiquitousStore.synchronize()
            if let raw = ubiquitousStore.string(forKey: storageKey),
               let theme = AppTheme(rawValue: raw),
               theme != selectedTheme {
                selectedTheme = theme
            } else if let raw = UserDefaults.standard.string(forKey: storageKey),
                      let theme = AppTheme(rawValue: raw),
                      theme != selectedTheme {
                selectedTheme = theme
            }

            if cloudObserver == nil {
                cloudObserver = NotificationCenter.default.addObserver(
                    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: ubiquitousStore,
                    queue: .main
                ) { [weak self] _ in
                    self?.storeChanged()
                }
            }

            // Push current theme to iCloud now that syncing is active.
            save()
        } else {
            if let cloudObserver {
                NotificationCenter.default.removeObserver(cloudObserver)
                self.cloudObserver = nil
            }

            // Ensure we use the locally stored theme when sync is disabled.
            if let raw = UserDefaults.standard.string(forKey: storageKey),
               let theme = AppTheme(rawValue: raw),
               theme != selectedTheme {
                selectedTheme = theme
            }
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        guard isSyncEnabled else { return }
        ubiquitousStore.set(selectedTheme.rawValue, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private func storeChanged() {
        guard isSyncEnabled else { return }
        ubiquitousStore.synchronize()
        if let raw = ubiquitousStore.string(forKey: storageKey),
           let theme = AppTheme(rawValue: raw),
           theme != selectedTheme {
            isApplyingRemoteChange = true
            selectedTheme = theme
            isApplyingRemoteChange = false
        }
    }
}

