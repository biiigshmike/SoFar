import SwiftUI

// MARK: - OnboardingView
/// Root container presenting a multi-step onboarding flow.
/// Steps:
/// 1. Welcome screen
/// 2. Category creation
/// 3. Card creation
/// 4. Preset creation
/// 5. iCloud sync configuration
/// 6. Loading completion screen
struct OnboardingView: View {
    // MARK: AppStorage
    /// Persisted flag indicating the user finished onboarding.
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false

    /// Cloud sync preferences stored globally so onboarding can opt the user in.
    @AppStorage(AppSettingsKeys.enableCloudSync.rawValue) private var enableCloudSync: Bool = false
    @AppStorage(AppSettingsKeys.syncCardThemes.rawValue) private var syncCardThemes: Bool = false
    @AppStorage(AppSettingsKeys.syncAppTheme.rawValue) private var syncAppTheme: Bool = false
    @AppStorage(AppSettingsKeys.syncBudgetPeriod.rawValue) private var syncBudgetPeriod: Bool = false

    // MARK: Step
    /// Enumeration of onboarding steps.
    enum Step: Int { case welcome, categories, cards, presets, cloudSync, loading }
    /// Current step in the flow.
    @State private var step: Step = .welcome

    // MARK: - Body
    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStep { step = .categories }
            case .categories:
                CategoriesStep { step = .cards }
            case .cards:
                CardsStep{ step = .presets }
            case .presets:
                PresetsStep { step = .cloudSync }
            case .cloudSync:
                CloudSyncStep(
                    enableCloudSync: $enableCloudSync,
                    syncCardThemes: $syncCardThemes,
                    syncAppTheme: $syncAppTheme,
                    syncBudgetPeriod: $syncBudgetPeriod
                ) { step = .loading }
            case .loading:
                LoadingStep {
                    didCompleteOnboarding = true
                }
            }
        }
        .animation(.easeInOut, value: step)
        .transition(.opacity)
        .onChange(of: enableCloudSync) { newValue in
            guard !newValue else { return }
            syncCardThemes = false
            syncAppTheme = false
            syncBudgetPeriod = false
        }
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
            Text("Welcome to Offshore Budgeting")
                .font(.largeTitle.bold())
            Text("Let's set up your budgeting workspace.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started") { onNext() }
//                .buttonStyle(.borderedProminent)
//                .buttonBorderShape(.roundedRectangle)
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
        NavigationStack {
            ZStack(alignment: .bottom) {
                CardsView()
                if showIntro {
                    introOverlay
                } else {
                    doneButton
                }
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
//                .buttonStyle(.borderedProminent)
        }
        .padding()
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    /// Bottom aligned button to continue after adding cards.
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
//                .buttonStyle(.borderedProminent)
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
        ZStack(alignment: .bottom) {
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
            Text("Presets are recurring expenses you have every month. Add them here so budgets are faster to create.")
                .multilineTextAlignment(.center)
            Button("Next") { withAnimation { showIntro = false } }
//                .buttonStyle(.borderedProminent)
        }
        .padding()
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
//                .buttonStyle(.borderedProminent)
                .padding()
        }
    }
}

// MARK: - CloudSyncStep
/// Gives users the option to enable iCloud syncing during onboarding.
/// - Parameters:
///   - enableCloudSync: Binding to the master iCloud sync toggle.
///   - syncCardThemes: Binding to the card appearance sync toggle.
///   - syncAppTheme: Binding to the app theme sync toggle.
///   - syncBudgetPeriod: Binding to the budget period sync toggle.
///   - onNext: Callback fired after the user makes a choice.
private struct CloudSyncStep: View {
    @Binding var enableCloudSync: Bool
    @Binding var syncCardThemes: Bool
    @Binding var syncAppTheme: Bool
    @Binding var syncBudgetPeriod: Bool
    let onNext: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("Sync with iCloud")
                        .font(.largeTitle.bold())
                    Text("Keep your budgets, themes, and settings up to date across every device signed into your iCloud account. You can change this anytime from Settings.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    Toggle("Enable iCloud Sync", isOn: $enableCloudSync)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Toggle("Sync card themes", isOn: $syncCardThemes)
                            .disabled(!enableCloudSync)
                        Toggle("Sync app appearance", isOn: $syncAppTheme)
                            .disabled(!enableCloudSync)
                        Toggle("Sync budget period", isOn: $syncBudgetPeriod)
                            .disabled(!enableCloudSync)
                    }
                    .foregroundStyle(enableCloudSync ? .primary : .secondary)
                    .opacity(enableCloudSync ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.2), value: enableCloudSync)

                    Text("We never see your data. Everything stays encrypted with your Apple ID and can be turned off later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.l)
                .cardBackground()

                Button(action: onNext) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.selectedTheme.tint)
            }
            .padding(.vertical, DS.Spacing.xl)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: enableCloudSync) { newValue in
            guard newValue else { return }
            if !syncCardThemes { syncCardThemes = true }
            if !syncAppTheme { syncAppTheme = true }
            if !syncBudgetPeriod { syncBudgetPeriod = true }
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
        NavigationStack {
            ZStack(alignment: .bottom) {
                ExpenseCategoryManagerView()
                if showIntro {
                    introOverlay
                } else {
                    doneButton
                }
            }
        }
    }

    // MARK: introOverlay
    private var introOverlay: some View {
        VStack(spacing: DS.Spacing.m) {
            Text("Create categories to track your spending. You can always edit them later.")
                .multilineTextAlignment(.center)
            Button("Next") { withAnimation { showIntro = false } }
//                .buttonStyle(.borderedProminent)
        }
        .padding()
        .cornerRadius(16)
        .padding()
    }

    // MARK: doneButton
    private var doneButton: some View {
        VStack {
            Spacer()
            Button("Done") { onNext() }
//                .buttonStyle(.borderedProminent)
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
