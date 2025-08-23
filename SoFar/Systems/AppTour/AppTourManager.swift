import SwiftUI

// MARK: - AppTourManager
/// Central controller responsible for the onboarding tour and contextual hints.
/// Add as an `EnvironmentObject` to access from any view.
@MainActor
final class AppTourManager: ObservableObject {
    // MARK: Tour State
    @AppStorage(AppSettingsKeys.completedAppTour.rawValue)
    private var completedAppTour: Bool = false

    /// When true a sheet presenting the onboarding tour is shown.
    @Published var showTour: Bool = false

    // MARK: Hint State
    @AppStorage(AppSettingsKeys.showHints.rawValue)
    var showHints: Bool = true { willSet { objectWillChange.send() } }

    @Published private(set) var activeHint: AppHint? = nil

    private let defaults = UserDefaults.standard
    private let shownHintsKey = "ShownAppHintIDs"

    init() {
        showTour = !completedAppTour
    }

    // MARK: Tour Methods
    func completeTour() {
        completedAppTour = true
        showTour = false
    }

    func restartTour() {
        completedAppTour = false
        showTour = true
    }

    // MARK: Hint Methods
    /// Determine whether a hint should be displayed.
    func shouldPresent(hint: AppHint) -> Bool {
        guard showHints else { return false }
        return !shownHintIDs.contains(hint.id)
    }

    /// Request presentation of a hint.
    func present(hint: AppHint) {
        guard shouldPresent(hint: hint) else { return }
        activeHint = hint
    }

    /// Dismiss the currently displayed hint and record it as shown.
    func dismissHint() {
        guard let id = activeHint?.id else { return }
        var ids = shownHintIDs
        ids.insert(id)
        shownHintIDs = ids
        activeHint = nil
    }

    /// Reset all hints so they will display again.
    func resetAllHints() {
        shownHintIDs = []
    }

    // MARK: Private
    private var shownHintIDs: Set<String> {
        get {
            guard let data = defaults.data(forKey: shownHintsKey),
                  let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: shownHintsKey)
        }
    }
}
