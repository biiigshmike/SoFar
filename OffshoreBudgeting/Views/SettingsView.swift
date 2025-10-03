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
    @Environment(\.platformCapabilities) private var capabilities
    @Environment(\.responsiveLayoutContext) private var responsiveLayoutContext

    @StateObject private var viewModel = SettingsViewModel()
    @State private var cloudStatusProvider: CloudAccountStatusProvider?
    @State private var availabilityCancellable: AnyCancellable?
    @State private var cloudAvailability: CloudAccountStatusProvider.Availability = .unknown
    @State private var showResetAlert: Bool = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    @AppStorage("UBForceLegacyChrome") private var forceLegacyChrome: Bool = false

    var body: some View {
        RootTabPageScaffold(
            scrollBehavior: .always,
            spacing: cardStackSpacing
        ) { proxy in
            let horizontalInset = resolvedHorizontalInset(using: proxy)

            RootViewTopPlanes(title: "Settings", titleDisplayMode: .hidden, horizontalPadding: horizontalInset)
                .padding(.top, scrollViewTopPadding)
        } content: { proxy in
            content(using: proxy)
        }
        .accentColor(themeManager.selectedTheme.resolvedTint)
        .tint(themeManager.selectedTheme.resolvedTint)
        .navigationTitle("Settings")
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
        .ub_onChange(of: viewModel.enableCloudSync, handleCloudSyncToggleChange)
        .ub_onChange(of: cloudAvailability, handleCloudAvailabilityChange)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func content(using proxy: RootTabPageProxy) -> some View {
        let tabBarGutter = proxy.compactAwareTabBarGutter
        let horizontalInset = resolvedHorizontalInset(using: proxy)

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

            // Appearance selection has been removed; app follows the System theme.

            // MARK: Sync Card (disabled)
            if false {
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

//f
        }
        .frame(maxWidth: .infinity)
        .rootTabContentPadding(
            proxy,
            horizontal: horizontalInset,
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

    private func handleCloudSyncToggleChange(_ isEnabled: Bool) {
        if isEnabled {
            Task { await requestCloudAvailabilityCheck(force: false) }
            if cloudAvailability == .available {
                Task { await CoreDataService.shared.applyCloudSyncPreferenceChange(enableSync: true) }
            }
        } else {
            Task { await CoreDataService.shared.applyCloudSyncPreferenceChange(enableSync: false) }
            cloudAvailability = .unknown
        }
    }

    private func handleCloudAvailabilityChange(_ availability: CloudAccountStatusProvider.Availability) {
        switch availability {
        case .available where viewModel.enableCloudSync:
            Task { await CoreDataService.shared.applyCloudSyncPreferenceChange(enableSync: true) }
        case .unavailable:
            if viewModel.enableCloudSync {
                viewModel.enableCloudSync = false
            }
        case .available, .unknown:
            break
        }
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

    private func resolvedHorizontalInset(using proxy: RootTabPageProxy?) -> CGFloat {
        if let proxy {
            return proxy.resolvedSymmetricHorizontalInset(capabilities: capabilities)
        }

        if capabilities.supportsOS26Translucency { return RootTabHeaderLayout.defaultHorizontalPadding }
        if responsiveLayoutContext.containerSize.width >= 600 { return RootTabHeaderLayout.defaultHorizontalPadding }

        let safeArea = responsiveLayoutContext.safeArea
        if safeArea.hasNonZeroInsets {
            return max(safeArea.leading, 0)
        }

        return max(horizontalSizeClass == .regular ? RootTabHeaderLayout.defaultHorizontalPadding : 0, 0)
    }

    private var cardStackSpacing: CGFloat {
        return horizontalSizeClass == .compact ? 10 : 16
    }

    private var scrollViewTopPadding: CGFloat {
        return horizontalSizeClass == .compact ? DS.Spacing.m : DS.Spacing.l
    }

    private func extraBottomPadding(
        using proxy: RootTabPageProxy,
        tabBarGutter: RootTabPageProxy.TabBarGutter
    ) -> CGFloat {
        let base = horizontalSizeClass == .compact ? 0 : DS.Spacing.l
        let tabChromeHeight: CGFloat = horizontalSizeClass == .compact ? 49 : 50
        let gutter = proxy.tabBarGutterSpacing(tabBarGutter)

        if capabilities.supportsOS26Translucency {
            // On OS26 we respect safe area; no extra is required beyond minor spacing.
            return max(base - gutter, 0)
        } else {
            // Legacy path: scaffold ignores the bottom safe area. Pad content by the
            // visible chrome (tab bar height) plus safe-area inset so the last card
            // remains fully visible above the opaque tab bar.
            let required = tabChromeHeight + proxy.safeAreaBottomInset
            return max(required + base - gutter, 0)
        }
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
