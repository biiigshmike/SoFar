//
//  OnboardingView.swift
//  SoFar
//
//  High-level onboarding flow shown on first launch.
//  Guides the user through adding cards, presets, and categories
//  before unlocking the main application.
//

import SwiftUI

// MARK: - OnboardingView
/// Entry point view for the onboarding sequence.
/// - Shows a series of steps: Welcome → Cards → Presets → Categories → Done.
/// - Callers provide a binding to `hasCompletedOnboarding` so this view can
///   dismiss itself when setup finishes.
struct OnboardingView: View {

    // MARK: User Defaults
    /// Binding used to persist whether onboarding has finished.
    /// - When set to `true`, the parent view can hide onboarding entirely.
    @Binding var hasCompletedOnboarding: Bool

    // MARK: Flow State
    /// Current step in the onboarding flow.
    @State private var step: Step = .welcome
    /// Controls whether the informational overlay is shown on the Presets step.
    @State private var showPresetInfo: Bool = true

    // MARK: Environment
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Step Enumeration
    /// Represents each screen in the onboarding flow.
    enum Step: Int {
        case welcome, cards, presets, categories, done
    }

    // MARK: Body
    var body: some View {
        ZStack {
            switch step {
            case .welcome: welcomeStep
            case .cards: cardsStep
            case .presets: presetsStep
            case .categories: categoriesStep
            case .done: doneStep
            }
        }
        .animation(.easeInOut, value: step)
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
    }

    // MARK: - Step Views

    // MARK: welcomeStep
    /// Initial welcome screen with a short greeting and a call-to-action button.
    /// - Returns: A view inviting the user to start setup.
    private var welcomeStep: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            Text("Welcome to SoFar")
                .font(.largeTitle).bold()
            Text("Let's get you set up.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started") { advance(to: .cards) }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, DS.Spacing.xl)
        }
        .transition(.opacity)
    }

    // MARK: cardsStep
    /// Step allowing the user to create one or more cards.
    /// - Uses existing `CardsView` styling for consistency.
    private var cardsStep: some View {
        ZStack(alignment: .bottom) {
            NavigationStack { CardsView() }
            Button("Done") { advance(to: .presets) }
                .buttonStyle(.borderedProminent)
                .padding(DS.Spacing.l)
        }
        .transition(.move(edge: .trailing))
    }

    // MARK: presetsStep
    /// Educates the user about presets and lets them add any recurring expenses.
    /// - Shows an informational overlay that blurs the background until dismissed.
    private var presetsStep: some View {
        ZStack {
            PresetsView()
                .blur(radius: showPresetInfo ? 8 : 0)

            if showPresetInfo {
                VStack(spacing: DS.Spacing.m) {
                    Text("Presets are expenses you pay regularly. Add them once and reuse them in future budgets.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    Button("Start Adding Presets") {
                        withAnimation { showPresetInfo = false }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .transition(.opacity)
            } else {
                VStack {
                    Spacer()
                    Button("Done") { advance(to: .categories) }
                        .buttonStyle(.borderedProminent)
                        .padding(DS.Spacing.l)
                }
                .transition(.opacity)
            }
        }
        .transition(.move(edge: .trailing))
    }

    // MARK: categoriesStep
    /// Final data-entry step where users define expense categories.
    /// - Returns: A view hosting `ExpenseCategoryManagerView` with a done button.
    private var categoriesStep: some View {
        ZStack(alignment: .bottom) {
            NavigationStack { ExpenseCategoryManagerView() }
            Button("Done") { advance(to: .done) }
                .buttonStyle(.borderedProminent)
                .padding(DS.Spacing.l)
        }
        .transition(.move(edge: .trailing))
    }

    // MARK: doneStep
    /// Simulates final setup work and marks onboarding as complete.
    /// - Returns: A progress view that dismisses after a short delay.
    private var doneStep: some View {
        VStack(spacing: DS.Spacing.l) {
            ProgressView("Setting up your app...")
                .padding()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        hasCompletedOnboarding = true
                    }
                }
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    // MARK: advance(to:)
    /// Animates to the provided onboarding step.
    /// - Parameter next: The next `Step` to display.
    private func advance(to next: Step) {
        withAnimation(.easeInOut) {
            step = next
        }
    }
}

