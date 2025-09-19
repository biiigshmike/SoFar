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
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

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
            OnboardingBackgroundSurface(
                tint: themeManager.selectedTheme.resolvedTint,
                baseColor: themeManager.selectedTheme.background,
                capabilities: capabilities
            )
            .ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeStep { step = .theme }
            case .theme:
                ThemeStep(
                    onNext: { step = .categories },
                    onBack: { step = .welcome }
                )
            case .categories:
                CategoriesStep(
                    onNext: { step = .cards },
                    onBack: { step = .theme }
                )
            case .cards:
                CardsStep(
                    onNext: { step = .presets },
                    onBack: { step = .categories }
                )
            case .presets:
                PresetsStep(
                    onNext: { step = .cloudSync },
                    onBack: { step = .cards }
                )
            case .cloudSync:
                CloudSyncStep(
                    enableCloudSync: $enableCloudSync,
                    syncCardThemes: $syncCardThemes,
                    syncAppTheme: $syncAppTheme,
                    syncBudgetPeriod: $syncBudgetPeriod
                ) {
                    step = .loading
                } onBack: {
                    step = .presets
                }
            case .loading:
                LoadingStep {
                    didCompleteOnboarding = true
                }
            }
        }
        .onboardingPresentation()
        .animation(.easeInOut, value: step)
        .transition(.opacity)
        .onChange(of: enableCloudSync) { _, newValue in
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

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            VStack(spacing: DS.Spacing.s) {
                Text("Welcome to Offshore Budgeting")
                    .font(.largeTitle.bold())
                Text("Let's set up your budgeting workspace.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 520)

            Spacer()

            OnboardingPrimaryButton(title: "Get Started", action: onNext)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ThemeStep
/// Lets users preview and select their preferred app theme before diving into setup.
/// - Parameters:
///   - onNext: Callback fired after the user confirms their choice.
///   - onBack: Callback fired when the user wants to return to the previous step.
private struct ThemeStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTheme: AppTheme = .system

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                themePicker
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text("You can change this anytime from Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    navigationButtons
                }
            }
            .padding(.vertical, DS.Spacing.xxl)
            .padding(.horizontal, DS.Spacing.xl)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { selectedTheme = themeManager.selectedTheme }
        .onChange(of: themeManager.selectedTheme) { _, newValue in
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
            LazyHStack(spacing: DS.Spacing.xl) {
                ForEach(AppTheme.allCases) { theme in
                    ThemePreviewTile(theme: theme, isSelected: theme == selectedTheme)
                        .onTapGesture { select(theme) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(theme.displayName))
                        .accessibilityAddTraits(theme == selectedTheme ? .isSelected : [])
                }
            }
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.m) {
            OnboardingSecondaryButton(title: "Back", action: onBack)
            OnboardingPrimaryButton(title: "Continue", action: onNext)
        }
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
        case .some(let scheme):
            switch scheme {
            case .dark:
                return .white
            case .light:
                return Color.black.opacity(0.9)
            @unknown default:
                return .primary
            }
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
        .frame(width: 260, height: 320)
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
/// - Parameters:
///   - onNext: Callback fired after user finishes adding cards.
///   - onBack: Callback fired when the user wants to revisit the previous step.
private struct CardsStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
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
        OnboardingGlassCard(alignment: .center) {
            Text("Add the cards you use for spending. We'll use them in budgets later.")
                .multilineTextAlignment(.center)
            OnboardingPrimaryButton(title: "Next") { withAnimation { showIntro = false } }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: doneButton
    /// Bottom aligned button to continue after adding cards.
    private var doneButton: some View {
        OnboardingGlassCard(
            alignment: .center,
            maxWidth: nil,
            contentPadding: .init(top: DS.Spacing.m, leading: DS.Spacing.xl, bottom: DS.Spacing.m, trailing: DS.Spacing.xl)
        ) {
            HStack(spacing: DS.Spacing.m) {
                OnboardingSecondaryButton(title: "Back", action: onBack)
                OnboardingPrimaryButton(title: "Done", action: onNext)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
    }
}

// MARK: - PresetsStep
/// Introduces planned expense presets.
/// - Parameters:
///   - onNext: Callback fired after user finishes adding presets.
///   - onBack: Callback fired when the user wants to revisit the previous step.
private struct PresetsStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
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
        OnboardingGlassCard(alignment: .center) {
            Text("Presets are recurring expenses you have every month. Add them here so budgets are faster to create.")
                .multilineTextAlignment(.center)
            OnboardingPrimaryButton(title: "Next") { withAnimation { showIntro = false } }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: doneButton
    private var doneButton: some View {
        OnboardingGlassCard(
            alignment: .center,
            maxWidth: nil,
            contentPadding: .init(top: DS.Spacing.m, leading: DS.Spacing.xl, bottom: DS.Spacing.m, trailing: DS.Spacing.xl)
        ) {
            HStack(spacing: DS.Spacing.m) {
                OnboardingSecondaryButton(title: "Back", action: onBack)
                OnboardingPrimaryButton(title: "Done", action: onNext)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
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
///   - onBack: Callback fired when the user wants to revisit the previous step.
private struct CloudSyncStep: View {
    @Binding var enableCloudSync: Bool
    @Binding var syncCardThemes: Bool
    @Binding var syncAppTheme: Bool
    @Binding var syncBudgetPeriod: Bool
    let onNext: () -> Void
    let onBack: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: enableCloudSync) { _, newValue in
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
            navigationButtons
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
        OnboardingGlassCard(
            alignment: .leading,
            maxWidth: 620,
            contentPadding: .init(
                top: DS.Spacing.xl,
                leading: DS.Spacing.xl,
                bottom: DS.Spacing.l,
                trailing: DS.Spacing.xl
            )
        ) {
            CloudOptionToggle(
                title: "Enable iCloud Sync",
                subtitle: "Keep budgets, themes, and settings identical everywhere.",
                isOn: $enableCloudSync,
                isEnabled: true
            )

            Divider()
                .opacity(0.25)
                .padding(.vertical, DS.Spacing.s)

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                CloudOptionToggle(
                    title: "Sync card themes",
                    subtitle: "Mirror your custom card colors across devices.",
                    isOn: $syncCardThemes,
                    isEnabled: enableCloudSync
                )

                CloudOptionToggle(
                    title: "Sync app appearance",
                    subtitle: "Use the same theme everywhere automatically.",
                    isOn: $syncAppTheme,
                    isEnabled: enableCloudSync
                )

                CloudOptionToggle(
                    title: "Sync budget period",
                    subtitle: "Align the start and end dates of each cycle.",
                    isOn: $syncBudgetPeriod,
                    isEnabled: enableCloudSync
                )
            }

            Text("We never see your data. Everything stays encrypted with your Apple ID and can be turned off later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Spacing.s)
        }
        .tint(themeManager.selectedTheme.resolvedTint)
    }

    private var navigationButtons: some View {
        HStack(spacing: DS.Spacing.m) {
            OnboardingSecondaryButton(title: "Back", action: onBack)
            OnboardingPrimaryButton(title: "Continue", action: onNext)
        }
    }
}

// MARK: - CategoriesStep
/// Lets users create expense categories.
/// - Parameters:
///   - onNext: Callback fired after categories are added.
///   - onBack: Callback fired when the user wants to revisit the previous step.
private struct CategoriesStep: View {
    let onNext: () -> Void
    let onBack: () -> Void
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
        OnboardingGlassCard(alignment: .center) {
            Text("Create categories to track your spending. You can always edit them later.")
                .multilineTextAlignment(.center)
            OnboardingPrimaryButton(title: "Next") { withAnimation { showIntro = false } }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: doneButton
    private var doneButton: some View {
        OnboardingGlassCard(
            alignment: .center,
            maxWidth: nil,
            contentPadding: .init(top: DS.Spacing.m, leading: DS.Spacing.xl, bottom: DS.Spacing.m, trailing: DS.Spacing.xl)
        ) {
            HStack(spacing: DS.Spacing.m) {
                OnboardingSecondaryButton(title: "Back", action: onBack)
                OnboardingPrimaryButton(title: "Done", action: onNext)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
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

// MARK: - Shared Components

private struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LiquidGlassButtonStyle(tint: themeManager.selectedTheme.resolvedTint))
    }
}

private struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            OnboardingSecondaryButtonStyle(tint: themeManager.selectedTheme.resolvedTint)
        )
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.platformCapabilities) private var capabilities

    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = 26

        return configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .padding(.vertical, DS.Spacing.m)
            .padding(.horizontal, DS.Spacing.l)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(background(isPressed: configuration.isPressed, radius: radius))
            .overlay(border(radius: radius, isPressed: configuration.isPressed))
            .overlay(highlight(radius: radius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool, radius: CGFloat) -> some View {
        if capabilities.supportsLiquidGlass, #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(isPressed ? 0.2 : 0.14))
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .compositingGroup()
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(isPressed ? 0.18 : 0.12))
        }
    }

    private func border(radius: CGFloat, isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(tint.opacity(isPressed ? 0.6 : 0.45), lineWidth: 1.5)
    }

    private func highlight(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                Color.white.opacity(capabilities.supportsLiquidGlass ? 0.22 : 0.14),
                lineWidth: 1
            )
            .blendMode(.screen)
    }
}

private struct OnboardingGlassCard<Content: View>: View {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    private let vStackAlignment: HorizontalAlignment
    private let frameAlignment: Alignment
    private let maxWidth: CGFloat?
    private let contentPadding: EdgeInsets
    private let content: Content

    init(
        alignment: Alignment = .leading,
        maxWidth: CGFloat? = 520,
        contentPadding: EdgeInsets = .init(top: DS.Spacing.xl, leading: DS.Spacing.xl, bottom: DS.Spacing.xl, trailing: DS.Spacing.xl),
        @ViewBuilder content: () -> Content
    ) {
        switch alignment {
        case .leading, .topLeading, .bottomLeading:
            self.vStackAlignment = .leading
            self.frameAlignment = .leading
        case .trailing, .topTrailing, .bottomTrailing:
            self.vStackAlignment = .trailing
            self.frameAlignment = .trailing
        default:
            self.vStackAlignment = .center
            self.frameAlignment = .center
        }

        self.maxWidth = maxWidth
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: vStackAlignment, spacing: DS.Spacing.l) {
            content
        }
        .padding(contentPadding)
        .frame(maxWidth: maxWidth ?? .infinity, alignment: frameAlignment)
        .background(
            OnboardingGlassBackground(
                tint: themeManager.selectedTheme.resolvedTint,
                capabilities: capabilities,
                cornerRadius: 32
            )
        )
    }
}

private struct OnboardingGlassBackground: View {
    let tint: Color
    let capabilities: PlatformCapabilities
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if capabilities.supportsLiquidGlass, #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.26))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1.1)
                            .blendMode(.screen)
                    )
                    .shadow(color: tint.opacity(0.24), radius: 30, x: 0, y: 18)
                    .compositingGroup()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(tint.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 10)
            }
        }
    }
}

private struct CloudOptionToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: DS.Spacing.m)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!isEnabled)
#if os(iOS) || os(macOS)
                .controlSize(.large)
#endif
        }
        .padding(.vertical, DS.Spacing.s)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

private struct OnboardingBackgroundSurface: View {
    let tint: Color
    let baseColor: Color
    let capabilities: PlatformCapabilities

    var body: some View {
        ZStack {
            baseColor

            if capabilities.supportsLiquidGlass, #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
                Rectangle()
                    .fill(tint.opacity(0.08))
                    .background(.ultraThinMaterial)
                    .overlay(glowOverlay)
                    .compositingGroup()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.94),
                                Color.white.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(glowOverlay)
            }
        }
    }

    private var glowOverlay: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.35),
                tint.opacity(0.05),
                .clear
            ]),
            center: .topLeading,
            startRadius: 40,
            endRadius: 600
        )
        .blendMode(.screen)
    }
}

private extension AppTheme {
    var resolvedTint: Color { tint ?? accent }
}
