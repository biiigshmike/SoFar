import SwiftUI

// MARK: - AppTheme
/// Centralized color palette for the application. Each case defines a
/// complete set of colours used across the UI so that switching themes is
/// consistent everywhere.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case classic
    case midnight
    case forest

    var id: String { rawValue }

    /// Human readable name shown in pickers.
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .forest: return "Forest"
        }
    }

    /// Accent colour applied to interactive elements.
    var accent: Color {
        switch self {
        case .classic: return .blue
        case .midnight: return .purple
        case .forest: return .green
        }
    }

    /// Primary background colour for views.
    var background: Color {
        switch self {
        case .classic: return Color(.systemBackground)
        case .midnight: return Color.black
        case .forest: return Color(red: 0.05, green: 0.14, blue: 0.10)
        }
    }

    /// Secondary background used for card interiors and icons.
    var secondaryBackground: Color {
        switch self {
        case .classic: return Color(.secondarySystemBackground)
        case .midnight: return Color(red: 0.15, green: 0.15, blue: 0.18)
        case .forest: return Color(red: 0.09, green: 0.20, blue: 0.15)
        }
    }

    /// Tertiary background for card shells.
    var tertiaryBackground: Color {
        switch self {
        case .classic: return Color(.tertiarySystemBackground)
        case .midnight: return Color(red: 0.12, green: 0.12, blue: 0.15)
        case .forest: return Color(red: 0.07, green: 0.16, blue: 0.12)
        }
    }
}

// MARK: - ThemeManager
/// Observable theme source of truth. Persists selection via `UserDefaults`
/// so the chosen theme survives app relaunches.
final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet { save() }
    }

    private let storageKey = "selectedTheme"

    init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let theme = AppTheme(rawValue: raw) {
            selectedTheme = theme
        } else {
            selectedTheme = .classic
        }
    }

    private func save() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
    }
}

