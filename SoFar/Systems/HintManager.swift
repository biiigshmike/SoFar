import SwiftUI
import Foundation

// MARK: - AppHint
/// Enumerates the various first-time hints shown across top-level views.
enum AppHint: String, CaseIterable, Identifiable {
    case home
    case income
    case cards
    case presets
    case settings

    var id: String { rawValue }

    /// Text displayed to the user when this hint is active.
    var message: String {
        switch self {
        case .home: return "View your current budget here.";
        case .income: return "Add income by tapping dates.";
        case .cards: return "Track spending on your cards.";
        case .presets: return "Save expenses to reuse later.";
        case .settings: return "Customize SoFar to your liking.";
        }
    }

    /// Persistent storage key marking this hint as seen.
    var storageKey: String { "hint_shown_" + rawValue }
}

// MARK: - HintManager
/// Centralized controller for displaying one-time onboarding hints.
@MainActor
final class HintManager: ObservableObject {
    /// Whether hints are globally enabled.
    @AppStorage(AppSettingsKeys.enableHints.rawValue)
    var hintsEnabled: Bool = true {
        willSet {
            objectWillChange.send()
            if !newValue { activeHint = nil }
        }
    }

    /// Currently active hint to present in the UI.
    @Published var activeHint: AppHint? = nil

    /// Request that a hint be shown if it hasn't been dismissed before.
    func present(_ hint: AppHint) {
        guard hintsEnabled else { return }
        let seen = UserDefaults.standard.bool(forKey: hint.storageKey)
        if !seen { activeHint = hint }
    }

    /// Dismisses the current hint and marks it as seen.
    func dismiss() {
        if let hint = activeHint {
            UserDefaults.standard.set(true, forKey: hint.storageKey)
        }
        activeHint = nil
    }

    /// Removes all hint markers so they will show again when requested.
    func reset() {
        for hint in AppHint.allCases {
            UserDefaults.standard.removeObject(forKey: hint.storageKey)
        }
        activeHint = nil
    }
}

// MARK: - HintBubble
/// Simple overlay bubble with a message, dismiss button, and optional idle animation.
struct HintBubble: View {
    let hint: AppHint
    let onDismiss: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var animate = false

    var body: some View {
        VStack(spacing: 8) {
            Text(hint.message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button("Got it", action: onDismiss)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.selectedTheme.accent.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(themeManager.selectedTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            Image(systemName: "arrow.down")
                .font(.title3)
                .foregroundColor(themeManager.selectedTheme.accent)
                .offset(y: 22)
                .opacity(animate ? 1 : 0.3)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate),
            alignment: .bottom
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                animate = true
            }
        }
    }
}
