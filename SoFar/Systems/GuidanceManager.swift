//
//  GuidanceManager.swift
//  SoFar
//
//  Created by OpenAI on 2024-05-30.
//
//  Central store for onboarding and contextual app hints.
//

import SwiftUI

// MARK: - GuidanceManager
/// Observable object that tracks whether the user has completed the initial
/// tour and which one-off hints have been dismissed. Inject into the
/// environment as `.environmentObject(GuidanceManager())`.
@MainActor
final class GuidanceManager: ObservableObject {

    // MARK: Storage Keys
    private enum Keys {
        static let hasSeenTour = "Guidance.hasSeenTour"
        static let hintsEnabled = "Guidance.hintsEnabled"
        static let dismissedHints = "Guidance.dismissedHints"
    }

    // MARK: Published Properties
    /// True once the user has completed the initial onboarding tour.
    @Published var hasSeenTour: Bool {
        didSet { defaults.set(hasSeenTour, forKey: Keys.hasSeenTour) }
    }

    /// Global switch controlling whether hints are displayed.
    @Published var hintsEnabled: Bool {
        didSet { defaults.set(hintsEnabled, forKey: Keys.hintsEnabled) }
    }

    /// Identifiers for hints the user has tapped to dismiss.
    @Published private(set) var dismissedHints: Set<String>

    // MARK: Private
    private let defaults: UserDefaults

    // MARK: Init
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenTour = defaults.bool(forKey: Keys.hasSeenTour)
        self.hintsEnabled = defaults.object(forKey: Keys.hintsEnabled) as? Bool ?? true
        self.dismissedHints = Set(defaults.stringArray(forKey: Keys.dismissedHints) ?? [])
    }

    // MARK: Hint Helpers
    /// Returns true if the hint with `id` should currently be shown.
    func shouldShowHint(id: String) -> Bool {
        hintsEnabled && !dismissedHints.contains(id)
    }

    /// Records `id` as dismissed so it won't appear again until reset.
    func dismissHint(id: String) {
        dismissedHints.insert(id)
        defaults.set(Array(dismissedHints), forKey: Keys.dismissedHints)
    }

    /// Clears all stored hint dismissals, allowing them to reappear.
    func resetHints() {
        dismissedHints.removeAll()
        defaults.removeObject(forKey: Keys.dismissedHints)
    }

    /// Marks the onboarding tour as incomplete so it will show again.
    func restartTour() {
        hasSeenTour = false
    }
}

// MARK: - AppHint Modifier
/// A view modifier that overlays a small bubble describing `text` the first
/// time the view appears. Tapping the bubble dismisses it.
struct AppHint: ViewModifier {
    @EnvironmentObject private var guidance: GuidanceManager
    let id: String
    let text: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if guidance.shouldShowHint(id: id) {
                    Text(text)
                        .font(.footnote)
                        .padding(8)
                        .foregroundStyle(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.systemYellow))
                        )
                        .shadow(radius: 2)
                        .padding(4)
                        .onTapGesture { guidance.dismissHint(id: id) }
                        .transition(.opacity)
                }
            }
    }
}

extension View {
    /// Adds a contextual hint that is displayed only once.
    /// - Parameters:
    ///   - id: Stable identifier for the hint. Prefer reverse-DNS style.
    ///   - text: Message to show.
    func appHint(id: String, text: String) -> some View {
        modifier(AppHint(id: id, text: text))
    }
}

