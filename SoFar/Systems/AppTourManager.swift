//
//  AppTourManager.swift
//  SoFar
//
//  Centralized onboarding and contextual hint system shared across iOS/iPadOS and macOS.
//  Attach hints to any view with the `.appHint` modifier and drive sequences via this manager.
//

import SwiftUI

// MARK: - AppTourStep
/// Single step in a guided tour or contextual hint.
struct AppTourStep: Identifiable, Equatable {
    let id: String
    let message: String
}

// MARK: - AppTourManager
@MainActor
final class AppTourManager: ObservableObject {

    // MARK: Stored Properties
    @AppStorage(AppSettingsKeys.hasCompletedAppTour.rawValue)
    private(set) var hasCompletedAppTour: Bool = false

    @AppStorage(AppSettingsKeys.showAppHints.rawValue)
    var showAppHints: Bool = true

    @Published private(set) var currentStep: AppTourStep?
    private var queue: [AppTourStep] = []

    // MARK: start(_:)
    /// Begin a tour with the supplied steps.
    func start(_ steps: [AppTourStep]) {
        guard showAppHints else { return }
        queue = steps
        next()
    }

    // MARK: startMainTour()
    /// Example default tour. Replace or extend with app-specific steps.
    func startMainTour() {
        start([
            AppTourStep(id: "rootTab", message: "Use the tabs below to navigate SoFar."),
            AppTourStep(id: "settings", message: "Adjust preferences from Settings at any time.")
        ])
    }

    // MARK: next()
    /// Advance to the next step in the queue.
    func next() {
        withAnimation {
            if queue.isEmpty {
                currentStep = nil
                hasCompletedAppTour = true
            } else {
                currentStep = queue.removeFirst()
            }
        }
    }

    // MARK: reset()
    /// Clears completion flag so tours can run again later.
    func reset() {
        hasCompletedAppTour = false
    }
}

// MARK: - AppHintBubble
/// Lightweight speech-bubble styled overlay used by the hint modifier.
private struct AppHintBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .padding(12)
            .multilineTextAlignment(.center)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
            )
            .padding()
    }
}

// MARK: - AppHintModifier
private struct AppHintModifier: ViewModifier {
    @ObservedObject var manager: AppTourManager
    let stepID: String
    let message: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .center) {
            if manager.currentStep?.id == stepID {
                AppHintBubble(text: message)
                    .onTapGesture { manager.next() }
            }
        }
    }
}

// MARK: - View+AppHint
extension View {
    /// Attach a guided hint to this view.
    /// - Parameters:
    ///   - id: Unique identifier for the step.
    ///   - manager: Shared `AppTourManager` environment object.
    ///   - message: Text displayed inside the hint bubble.
    /// - Returns: Modified view displaying the hint when active.
    func appHint(_ id: String, manager: AppTourManager, message: String) -> some View {
        modifier(AppHintModifier(manager: manager, stepID: id, message: message))
    }
}
