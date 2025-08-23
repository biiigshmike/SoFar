import SwiftUI

// MARK: - AppHint
/// Unique identifiers for one-time onboarding hints.
enum AppHint: String, CaseIterable {
    case home
    case income
    case cards
    case presets
    case settings
}

// MARK: - AppHintManager
/// Centralized controller that tracks which hints have been shown and
/// whether hints are globally enabled. Hints are stored in `UserDefaults`
/// so they persist across launches and devices.
final class AppHintManager: ObservableObject {
    /// Global toggle for enabling or disabling hints entirely.
    @AppStorage(AppSettingsKeys.showHints.rawValue)
    var hintsEnabled: Bool = true { willSet { objectWillChange.send() } }

    /// Returns true if the hint should be displayed.
    func shouldShow(_ hint: AppHint) -> Bool {
        hintsEnabled && !UserDefaults.standard.bool(forKey: key(for: hint))
    }

    /// Marks a hint as seen so it will no longer be displayed.
    func markShown(_ hint: AppHint) {
        UserDefaults.standard.set(true, forKey: key(for: hint))
        objectWillChange.send()
    }

    /// Removes all stored hint flags, allowing them to appear again.
    func resetAll() {
        for hint in AppHint.allCases {
            UserDefaults.standard.removeObject(forKey: key(for: hint))
        }
        objectWillChange.send()
    }

    // MARK: Key Helpers
    private func key(for hint: AppHint) -> String {
        "hint." + hint.rawValue
    }
}

// MARK: - AppHintViewModifier
/// Overlays a dismissible hint near the tab bar when appropriate.
struct AppHintViewModifier: ViewModifier {
    @EnvironmentObject private var hintManager: AppHintManager
    @EnvironmentObject private var themeManager: ThemeManager
    let hint: AppHint
    let message: String
    @State private var showPulse: Bool = false

    func body(content: Content) -> some View {
        ZStack {
            content
            if hintManager.shouldShow(hint) {
                hintOverlay
                    .transition(.opacity)
                    .onAppear { startPulseTimer() }
            }
        }
    }

    // MARK: Hint UI
    private var hintOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: DS.Spacing.s) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(DS.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(themeManager.selectedTheme.secondaryBackground)
                    )
                Button("Got it") {
                    hintManager.markShown(hint)
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(.bottom, 70)
            .overlay(alignment: .bottom) {
                if showPulse {
                    Image(systemName: "hand.tap")
                        .foregroundColor(themeManager.selectedTheme.accent)
                        .padding(.top, DS.Spacing.m)
                        .scaleEffect(showPulse ? 1.1 : 0.9)
                        .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: showPulse)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Pulse Timer
    private func startPulseTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showPulse = true
        }
    }
}

// MARK: - View+AppHint
extension View {
    /// Displays a one-time hint message for the given identifier.
    func appHint(_ hint: AppHint, message: String) -> some View {
        modifier(AppHintViewModifier(hint: hint, message: message))
    }
}
