//
//  AppHints.swift
//  SoFar
//
//  Centralised helper for presenting first-time tours and contextual hints.
//  Attach `AppHintManager` as an environment object to allow any view to
//  request hints. Hints are queued so they never overlap and are persisted
//  so users are not shown the same hint twice.
//

import SwiftUI
import Combine

// MARK: - AppHint
/// Unique identifiers for user-facing hints in the app.
/// Extend this enum with additional cases for new hints.
enum AppHint: String, CaseIterable, Identifiable {
    case welcome
    case homeAddBudget

    var id: String { rawValue }

    /// Human readable text shown to the user.
    var message: String {
        switch self {
        case .welcome:
            return "Welcome to SoFar! Let's take a quick look around."
        case .homeAddBudget:
            return "Tap the + button to create your first budget."
        }
    }
}

// MARK: - AppHintManager
/// Manages which hints have been displayed and coordinates presentation.
/// The manager queues incoming hints so they appear one at a time.
@MainActor
final class AppHintManager: ObservableObject {
    // MARK: Stored Properties

    /// Toggle controlling whether hints are displayed at all.
    @AppStorage(AppSettingsKeys.showHints.rawValue)
    var hintsEnabled: Bool = true {
        willSet { objectWillChange.send() }
        didSet {
            if !hintsEnabled {
                queue.removeAll()
                activeHint = nil
            }
        }
    }

    /// Identifiers of hints the user has already seen.
    @AppStorage("seenHints") private var seenHintsData: Data = Data()
    private var seenHints: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: seenHintsData)) ?? [] }
        set { seenHintsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Currently presented hint.
    @Published var activeHint: AppHint?

    /// Pending hints waiting to be shown.
    private var queue: [AppHint] = []

    // MARK: Hint Presentation
    /// Request that a hint be displayed. If another hint is active the
    /// request is queued. Hints are skipped when disabled or already seen.
    func show(_ hint: AppHint) {
        guard hintsEnabled, !seenHints.contains(hint.id) else { return }
        if activeHint == nil {
            activeHint = hint
        } else if !queue.contains(hint) {
            queue.append(hint)
        }
    }

    /// Mark the supplied hint as handled and present the next one in the queue.
    func markSeen(_ hint: AppHint) {
        seenHints.insert(hint.id)
        if activeHint?.id == hint.id {
            activeHint = nil
        }
        if !queue.isEmpty {
            activeHint = queue.removeFirst()
        }
    }

    /// Clears all saved hint state so the full tour can run again.
    func reset() {
        seenHints = []
        queue.removeAll()
        activeHint = nil
    }
}

// MARK: - View Convenience
private struct AppHintPresenter: ViewModifier {
    @EnvironmentObject private var hintManager: AppHintManager
    let hint: AppHint

    func body(content: Content) -> some View {
        content.onAppear { hintManager.show(hint) }
    }
}

extension View {
    /// Request that a particular hint be shown when this view appears.
    /// - Parameter hint: The `AppHint` to display.
    /// - Returns: A view that triggers the hint system on appear.
    func appHint(_ hint: AppHint) -> some View {
        modifier(AppHintPresenter(hint: hint))
    }
}
