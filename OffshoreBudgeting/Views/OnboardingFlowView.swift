//
//  OnboardingFlowView.swift
//  SoFar
//
//  Sequential introduction for first-time users.
//  Guides through adding cards, presets, and categories before entering the main app.
//

import SwiftUI
import CoreData

// MARK: - OnboardingFlowView
/// Multi-step onboarding wizard displayed on first launch.
/// - After completion, executes `onFinished` so the app can transition to main content.
struct OnboardingFlowView: View {

    // MARK: Step
    private enum Step {
        case welcome
        case cards
        case presets
        case categories
        case finish
    }

    // MARK: State
    @State private var currentStep: Step = .welcome

    // MARK: Callbacks
    /// Invoked when the onboarding flow finishes.
    var onFinished: () -> Void

    // MARK: Body
    var body: some View {
        switch currentStep {
        case .welcome:
            WelcomeStep { currentStep = .cards }
        case .cards:
            CardSetupStep { currentStep = .presets }
        case .presets:
            PresetSetupStep { currentStep = .categories }
        case .categories:
            CategorySetupStep { currentStep = .finish }
        case .finish:
            FinalizeStep { onFinished() }
        }
    }
}

// MARK: - WelcomeStep
/// First page introducing the app with a call to action.
private struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            Text("Welcome to SoFar")
                .font(.largeTitle.weight(.bold))
            Text("Let's get your budgeting workspace ready.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.l)
            Spacer()
            Button("Get Started") { onNext() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

// MARK: - CardSetupStep
/// Screen allowing users to add any spending cards they wish to track.
/// Displays cards with existing `CardTileView` styling and loops until the user taps Next.
private struct CardSetupStep: View {
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: Services
    private let cardService = CardService()

    // MARK: Local State
    @State private var cards: [Card] = []
    @State private var showingAddCard = false

    var onNext: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Text("Add Your Cards")
                .font(.title2.bold())
            ScrollView {
                LazyVStack(spacing: DS.Spacing.m) {
                    ForEach(cards, id: \.objectID) { card in
                        CardTileView(card: CardItem(from: card))
                            .padding(.horizontal, DS.Spacing.l)
                    }
                }
                .padding(.top, DS.Spacing.m)
            }
            Button("Add Card") { showingAddCard = true }
                .buttonStyle(.bordered)
            Button("Next") { onNext() }
                .buttonStyle(.borderedProminent)
                .padding(.top, DS.Spacing.s)
        }
        .task { refreshCards() }
        .sheet(isPresented: $showingAddCard) {
            AddCardFormView { name, theme in
                do {
                    let saved = try cardService.createCard(name: name)
                    if let id = saved.value(forKey: "id") as? UUID {
                        CardAppearanceStore.shared.setTheme(theme, for: id)
                    }
                    refreshCards()
                } catch {
                    // Saving is best-effort during onboarding; simply refresh.
                    refreshCards()
                }
            }
            .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: refreshCards()
    /// Fetches current cards from storage into local state.
    private func refreshCards() {
        cards = (try? cardService.fetchAllCards()) ?? []
    }
}

// MARK: - PresetSetupStep
/// Introduces users to Presets with a brief description overlay that fades away.
/// Behind the overlay, the standard `PresetsView` is visible and ready for input.
private struct PresetSetupStep: View {
    @State private var showIntro = true
    var onNext: () -> Void

    var body: some View {
        ZStack {
            PresetsView()
                .blur(radius: showIntro ? 4 : 0)
                .disabled(showIntro)

            if showIntro {
                VStack(spacing: DS.Spacing.m) {
                    Text("Presets let you save monthly expenses so creating budgets is faster.")
                        .multilineTextAlignment(.center)
                    Button("Next") {
                        withAnimation(.easeOut) { showIntro = false }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            } else {
                VStack {
                    Spacer()
                    Button("Next") { onNext() }
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
        }
    }
}

// MARK: - CategorySetupStep
/// Allows users to define any expense categories up front using the existing manager view.
private struct CategorySetupStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack {
            ExpenseCategoryManagerView()
            Button("Next") { onNext() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - FinalizeStep
/// Final screen that simulates configuration before handing off to the app.
private struct FinalizeStep: View {
    var onFinished: () -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            if isLoading {
                ProgressView("Setting up your app…")
                    .task {
                        // Simulate a short setup delay
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        onFinished()
                    }
            } else {
                Text("All set?")
                    .font(.title2.bold())
                Button("Done") {
                    withAnimation { isLoading = true }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

