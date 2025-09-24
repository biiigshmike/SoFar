//
//  SettingsView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI
import Combine

// MARK: - SettingsView
/// Root settings screen with a hero-style "General" card and smaller cards below.
/// Cards embed toggles and navigation links; everything scales across iPhone, iPad, and Mac.
/// Integrate into your tab or navigation stack directly.
struct SettingsView: View {

    // MARK: Dependencies
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    @StateObject private var viewModel = SettingsViewModel()
    @State private var cloudStatusProvider: CloudAccountStatusProvider?
    @State private var availabilityCancellable: AnyCancellable?
    @State private var cloudAvailability: CloudAccountStatusProvider.Availability = .unknown
    @State private var showResetAlert: Bool = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false

    var body: some View {
        RootTabPageScaffold(
            scrollBehavior: .always,
            spacing: cardStackSpacing
        ) { _ in
            RootViewTopPlanes(title: "Settings", horizontalPadding: horizontalPadding)
                .padding(.top, scrollViewTopPadding)
        } content: { proxy in
            content(using: proxy)
        }
        .accentColor(themeManager.selectedTheme.resolvedTint)
        .tint(themeManager.selectedTheme.resolvedTint)
        .ub_tabNavigationTitle("Settings")
        .alert("Erase All Data?", isPresented: $showResetAlert) {
            Button("Erase", role: .destructive) {
                try? CoreDataService.shared.wipeAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all budgets, cards, incomes, and expenses. This action cannot be undone.")
        }
        .task {
            if viewModel.enableCloudSync {
                await requestCloudAvailabilityCheck(force: false)
            }
        }
        .ub_onChange(of: viewModel.enableCloudSync) { newValue in
            if newValue {
                Task { await requestCloudAvailabilityCheck(force: false) }
            } else {
                cloudAvailability = .unknown
            }
        }
        .ub_onChange(of: cloudAvailability) { availability in
            guard availability == .unavailable else { return }
            viewModel.enableCloudSync = false
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func content(using proxy: RootTabPageProxy) -> some View {
        let tabBarGutter = proxy.compactAwareTabBarGutter

        VStack(spacing: cardStackSpacing) {
            // MARK: General Hero Card
            SettingsCard(
                iconSystemName: "gearshape",
                title: "General",
                subtitle: "Manage default behaviors."
            ) {
                VStack(spacing: 0) {
                    SettingsRow(title: "Confirm Before Deleting", showsTopDivider: false) {
                        Toggle("", isOn: $viewModel.confirmBeforeDelete)
                            .labelsHidden()
                    }
                    SettingsRow(title: "Default Budget Period") {
                        Picker("", selection: $viewModel.budgetPeriod) {
                            ForEach(BudgetPeriod.selectableCases) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Appearance Card
            SettingsCard(
                iconSystemName: "paintpalette",
                title: "Appearance",
                subtitle: "Select a theme for the app.",
            ) {
                VStack(spacing: 0) {
                    SettingsRow(title: "Theme", showsTopDivider: false) {
                        Picker("", selection: $themeManager.selectedTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .labelsHidden()
                    }

                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Sync Card
            SettingsCard(
                iconSystemName: "icloud",
                title: "iCloud Services",
                subtitle: "Sync your data and settings across your devices signed into the same iCloud account.",
            ) {
                VStack(spacing: 0) {
                    SettingsRow(title: "Enable iCloud Sync", showsTopDivider: false) {
                        Toggle("", isOn: $viewModel.enableCloudSync)
                            .labelsHidden()
                            .disabled(!canUseCloudSync)
                    }
                    .opacity(canUseCloudSync ? 1 : 0.5)
                    SettingsRow(title: "Sync Card Themes Across Devices") {
                        Toggle("", isOn: $viewModel.syncCardThemes)
                            .labelsHidden()
                    }
                    .disabled(!viewModel.enableCloudSync || !canUseCloudSync)
                    .opacity(viewModel.enableCloudSync && canUseCloudSync ? 1 : 0.5)

                    SettingsRow(title: "Sync App Theme Across Devices") {
                        Toggle("", isOn: $viewModel.syncAppTheme)
                            .labelsHidden()
                    }
                    .disabled(!viewModel.enableCloudSync || !canUseCloudSync)
                    .opacity(viewModel.enableCloudSync && canUseCloudSync ? 1 : 0.5)
                    SettingsRow(title: "Sync Budget Period Across Devices") {
                        Toggle("", isOn: $viewModel.syncBudgetPeriod)
                            .labelsHidden()
                    }
                    .disabled(!viewModel.enableCloudSync || !canUseCloudSync)
                    .opacity(viewModel.enableCloudSync && canUseCloudSync ? 1 : 0.5)
                    if isCheckingCloudAvailability {
                        Divider()
                            .padding(.vertical, 8)
                            .opacity(0.2)

                        Text("Checking your iCloud status…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    } else if isCloudUnavailable {
                        Divider()
                            .padding(.vertical, 8)
                            .opacity(0.2)

                        Text("iCloud is currently unavailable. Sync options will unlock when an iCloud account is signed in and reachable.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

//            // MARK: Calendar Card
//            SettingsCard(
//                iconSystemName: "calendar",
//                title: "Calendar",
//                subtitle: "Choose how your income calendar is presented."
//            ) {
//                VStack(spacing: 0) {
//                    SettingsRow(title: "Horizontal Scrolling") {
//                        Toggle("", isOn: $viewModel.calendarHorizontal)
//                            .labelsHidden()
//                    }
//                }
//                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//            }

            // MARK: Presets Card
            SettingsCard(
                iconSystemName: "list.bullet.rectangle",
                title: "Presets",
                subtitle: "Planned Expenses default to being created as a Preset Planned Expense."
            ) {
                VStack(spacing: 0) {
                    SettingsRow(title: "Use in Future Budgets by Default", showsTopDivider: false) {
                        Toggle("", isOn: $viewModel.presetsDefaultUseInFutureBudgets)
                            .labelsHidden()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Expenses Card (with sub-page)
            SettingsCard(
                iconSystemName: "tag",
                title: "Expense Categories",
                subtitle: "Manage expense categories for Variable Expenses."
            ) {
                VStack(spacing: 0) {
                    NavigationLink {
                        ExpenseCategoryManagerView()
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        SettingsRow(title: "Manage Categories", detail: "Open", showsTopDivider: false) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Help Card
            SettingsCard(
                iconSystemName: "book",
                title: "Help",
                subtitle: "Open the in-app guide.",
            ) {
                VStack(spacing: 0) {
                    NavigationLink {
                        HelpView()
                    } label: {
                        SettingsRow(title: "View Help", detail: "Open", showsTopDivider: false) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Onboarding Card
            SettingsCard(
                iconSystemName: "questionmark.circle",
                title: "Onboarding",
                subtitle: "Replay the initial setup flow.",
            ) {
                VStack(spacing: 0) {
                    Button {
                        didCompleteOnboarding = false
                    } label: {
                        SettingsRow(title: "Repeat Onboarding Process", showsTopDivider: false) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // MARK: Reset Card
            SettingsCard(
                iconSystemName: "trash",
                title: "Reset",
                subtitle: "Clear all stored data."
            ) {
                VStack(spacing: 0) {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        SettingsRow(title: "Erase All Data", showsTopDivider: false) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .rootTabContentPadding(
            proxy,
            horizontal: horizontalPadding,
            extraBottom: extraBottomPadding(
                using: proxy,
                tabBarGutter: tabBarGutter
            ),
            includeSafeArea: false,
            tabBarGutter: tabBarGutter
        )
    }

    @MainActor
    private func ensureCloudStatusProvider() -> CloudAccountStatusProvider {
        if let provider = cloudStatusProvider {
            return provider
        }

        let provider = CloudAccountStatusProvider.shared
        cloudStatusProvider = provider
        subscribe(to: provider)
        return provider
    }

    @MainActor
    private func subscribe(to provider: CloudAccountStatusProvider) {
        availabilityCancellable?.cancel()
        cloudAvailability = provider.availability
        availabilityCancellable = provider.availabilityPublisher
            .sink { availability in
                Task { @MainActor in
                    cloudAvailability = availability
                }
            }
    }

    private func requestCloudAvailabilityCheck(force: Bool) async {
        let provider = await MainActor.run { ensureCloudStatusProvider() }
        _ = await provider.resolveAvailability(forceRefresh: force)
    }

    private var canUseCloudSync: Bool {
        cloudAvailability == .available
    }

    private var isCloudUnavailable: Bool {
        cloudAvailability == .unavailable
    }

    private var isCheckingCloudAvailability: Bool {
        viewModel.enableCloudSync && cloudAvailability == .unknown
    }

    /// Balanced padding across platforms; a little more breathing room on larger screens.
    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 24
        #else
        return horizontalSizeClass == .regular ? 24 : 16
        #endif
    }

    private var cardStackSpacing: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? 10 : 16
        #else
        return 16
        #endif
    }

    private var scrollViewTopPadding: CGFloat {
        #if os(iOS)
        return horizontalSizeClass == .compact ? DS.Spacing.m : DS.Spacing.l
        #else
        return DS.Spacing.l
        #endif
    }

    private func extraBottomPadding(
        using proxy: RootTabPageProxy,
        tabBarGutter: RootTabPageProxy.TabBarGutter
    ) -> CGFloat {
        #if os(iOS)
        let base = horizontalSizeClass == .compact ? 0 : DS.Spacing.l
        let tabChromeHeight: CGFloat = horizontalSizeClass == .compact ? 49 : 50
        let overflow = max(proxy.safeAreaBottomInset - tabChromeHeight, 0)
        return max(base + overflow - proxy.tabBarGutterSpacing(tabBarGutter), 0)
        #else
        return max(DS.Spacing.l - proxy.tabBarGutterSpacing(tabBarGutter), 0)
        #endif
    }

}

// MARK: - Platform-Safe Modifiers
extension View {
    // MARK: applyInlineNavTitleOnIOS()
    /// Sets `.navigationBarTitleDisplayMode(.inline)` on iOS only; is a no-op on macOS.
    /// - Use when you want inline titles on iPhone/iPad but need to compile on Mac as well.
    @ViewBuilder
    func applyInlineNavTitleOnIOS() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
