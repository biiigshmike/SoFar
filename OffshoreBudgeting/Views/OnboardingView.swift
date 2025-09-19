import SwiftUI

// MARK: - OnboardingView
/// Root container presenting a multi-step onboarding flow.
/// Steps:
/// 1. Welcome screen
/// 2. Theme selection
/// 3. Category creation
/// 4. Card creation
/// 5. Preset creation
/// 6. iCloud sync configuration
/// 7. Loading completion screen
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
    enum Step: Int { case welcome, theme, categories, cards, presets, cloudSync, loading }
    /// Current step in the flow.
    @State private var step: Step = .welcome

    // MARK: - Body
    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeStep { step = .theme }
            case .theme:
                ThemeStep { step = .categories }
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

// MARK: - ThemeStep
/// Lets users preview and select their preferred app theme before diving into setup.
/// - Parameter onNext: Callback fired after the user confirms their choice.
private struct ThemeStep: View {
    let onNext: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTheme: AppTheme = .system

    var body: some View {
        ZStack {
            themeManager.selectedTheme.background
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header
                    themePicker
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text("You can change this anytime from Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        continueButton
                    }
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.xl)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { selectedTheme = themeManager.selectedTheme }
        .onChange(of: themeManager.selectedTheme) { newValue in
            guard newValue != selectedTheme else { return }
            selectedTheme = newValue
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Choose Your Theme")
                .font(.largeTitle.bold())
            Text("Preview each style instantly to see how cards, backgrounds, and accents adapt.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var themePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.l) {
                ForEach(AppTheme.allCases) { theme in
                    ThemePreviewTile(theme: theme, isSelected: theme == selectedTheme)
                        .onTapGesture { select(theme) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(theme.displayName))
                        .accessibilityAddTraits(theme == selectedTheme ? .isSelected : [])
                }
            }
            .padding(.vertical, DS.Spacing.s)
            .padding(.trailing, DS.Spacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var continueButton: some View {
        Button(action: onNext) {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(themeManager.selectedTheme.tint)
        .padding(.top, DS.Spacing.m)
    }

    private func select(_ theme: AppTheme) {
        guard theme != selectedTheme else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedTheme = theme
            themeManager.selectedTheme = theme
        }
    }
}

// MARK: ThemePreviewTile
private struct ThemePreviewTile: View {
    let theme: AppTheme
    let isSelected: Bool

    private var outlineColor: Color { theme.tint ?? theme.accent }

    private var textColor: Color {
        switch theme.colorScheme {
        case .some(.dark):
            return .white
        case .some(.light):
            return Color.black.opacity(0.9)
        case nil:
            return .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.secondaryBackground)
                    .overlay(cardDemo)
                Circle()
                    .fill(outlineColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .offset(x: 110, y: -26)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(theme.displayName)
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text("Rich gradients, glass, and accents tailored to this palette.")
                    .font(.footnote)
                    .foregroundStyle(textColor.opacity(0.7))
            }
        }
        .padding(DS.Spacing.l)
        .frame(width: 240, height: 300)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(outlineColor.opacity(isSelected ? 1 : 0.0), lineWidth: isSelected ? 3 : 0)
        )
        .shadow(color: .black.opacity(isSelected ? 0.22 : 0.12), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isSelected)
    }

    private var cardDemo: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((theme.tint ?? theme.accent).opacity(0.85))
                .frame(height: 40)
                .overlay(
                    HStack {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 70, height: 8)
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 18, height: 18)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Capsule()
                    .fill((theme.secondaryAccent).opacity(0.9))
                    .frame(width: 90, height: 10)
                Capsule()
                    .fill((theme.accent).opacity(0.55))
                    .frame(width: 60, height: 10)
                Capsule()
                    .fill((theme.accent).opacity(0.35))
                    .frame(width: 110, height: 10)
            }

            Spacer()

            HStack(spacing: DS.Spacing.s) {
                Capsule()
                    .fill((theme.tint ?? theme.accent).opacity(0.9))
                    .frame(width: 70, height: 22)
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 22)
            }
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
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: enableCloudSync) { newValue in
            guard newValue else { return }
            if !syncCardThemes { syncCardThemes = true }
            if !syncAppTheme { syncAppTheme = true }
            if !syncBudgetPeriod { syncBudgetPeriod = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            header
            cloudOptionsCard
            continueButton
        }
        .padding(.vertical, DS.Spacing.xxl)
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Sync with iCloud")
                .font(.largeTitle.bold())
            Text("Keep your budgets, themes, and settings up to date across every device signed into your iCloud account. You can change this anytime from Settings.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cloudOptionsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            Toggle("Enable iCloud Sync", isOn: $enableCloudSync)
                .font(.headline)

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
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
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var continueButton: some View {
        Button(action: onNext) {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(themeManager.selectedTheme.tint)
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
