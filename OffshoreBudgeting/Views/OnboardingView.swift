//
//  OnboardingView.swift
//  SoFar
//
//  First-run experience guiding new users through initial setup.
//

import SwiftUI

// MARK: - OnboardingView
/// Root container presenting a multi-step onboarding flow.
/// Steps:
/// 1. Welcome screen
/// 2. Card creation
/// 3. Preset creation
/// 4. Expense category creation
/// 5. Loading completion screen
struct OnboardingView: View {
    // MARK: AppStorage
    /// Persisted flag indicating the user finished onboarding.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false

    // MARK: Step
    /// Enumeration of onboarding steps.
    enum Step: Int { case welcome, cards, presets, categories, loading }
    /// Current step in the flow.
    @State private var step: Step = .welcome

    // MARK: - Body
    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStep { step = .cards }
            case .cards:
                CardsStep { step = .presets }
            case .presets:
                PresetsStep { step = .categories }
            case .categories:
                CategoriesStep { step = .loading }
            case .loading:
                LoadingStep {
                    didCompleteOnboarding = true
                }
            }
        }
        .animation(.easeInOut, value: step)
        .transition(.opacity)
    }
}

// MARK: - WelcomeStep
/// Greets the user and begins onboarding.
/// - Parameter onNext: Callback fired when user taps "Get Started".
private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            Text("Welcome to SoFar")
                .font(.largeTitle.bold())
            Text("Let's set up your budgeting workspace.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started") { onNext() }
                .buttonStyle(.borderedProminent)
        }
        .padding(DS.Spacing.l)
    }
}

// MARK: - CardsStep
/// Allows users to add cards before proceeding.
/// - Parameter onNext: Callback fired after user finishes adding cards.
private struct CardsStep: View {
    let onNext: () -> Void
    @State private var showIntro: Bool = true

    var body: some View {
        ZStack {
            CardsView()
            if showIntro {
                introOverlay
            } else {
                doneButton
            }
        }
    }

    // MARK: introOverlay
    /// Instruction overlay with blurred background.
    private var introOverlay: some View {
        VStack(spacing: DS.Spacing.m) {
            Text("Add the cards you use for spending. We'll use them in budgets later.")
                .multilineTextAlignment(.center)
            Button("Next") { withAnimation { showIntro = false } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    /// Bottom aligned button to continue after adding cards.
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - PresetsStep
/// Introduces planned expense presets.
/// - Parameter onNext: Callback fired after user finishes adding presets.
private struct PresetsStep: View {
    let onNext: () -> Void
    @State private var showIntro: Bool = true

    var body: some View {
        ZStack {
            PresetsView()
            if showIntro {
                introOverlay
            } else {
                doneButton
            }
        }
    }

    // MARK: introOverlay
    private var introOverlay: some View {
        VStack(spacing: DS.Spacing.m) {
            Text("Presets are recurring expenses you have every month. Add them here so budgets are faster to build.")
                .multilineTextAlignment(.center)
            Button("Next") { withAnimation { showIntro = false } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - CategoriesStep
/// Lets users create expense categories.
/// - Parameter onNext: Callback fired after categories are added.
private struct CategoriesStep: View {
    let onNext: () -> Void
    @State private var showIntro: Bool = true

    var body: some View {
        ZStack {
            ExpenseCategoryManagerView()
            if showIntro {
                introOverlay
            } else {
                doneButton
            }
        }
    }

    // MARK: introOverlay
    private var introOverlay: some View {
        VStack(spacing: DS.Spacing.m) {
            Text("Create categories to track your spending. You can always edit them later.")
                .multilineTextAlignment(.center)
            Button("Next") { withAnimation { showIntro = false } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - LoadingStep
/// Simulates loading before completing onboarding.
/// - Parameter onFinish: Callback fired after the simulated delay.
private struct LoadingStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            ProgressView()
            Text("Preparing your workspace…")
                .foregroundStyle(.secondary)
        }
        .task {
            // Simulate a brief loading delay then finish.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            onFinish()
        }
        .padding()
    }
}

