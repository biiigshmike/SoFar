//
//  SettingsView.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import SwiftUI

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
    @State private var showResetAlert: Bool = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false

    var body: some View {
        ScrollView {

            VStack(spacing: 16) {

                // MARK: General Hero Card
                SettingsCard(
                    iconSystemName: "gearshape",
                    title: "General",
                    subtitle: "Manage default behaviors."
                ) {
                    VStack(spacing: 0) {
                        SettingsRow(title: "Confirm Before Deleting") {
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
                        SettingsRow(title: "Theme") {
                            Picker("", selection: $themeManager.selectedTheme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .labelsHidden()
                        }

                        if themeManager.selectedTheme == .liquidGlass {
                            LiquidGlassCustomizationControls()
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
                        SettingsRow(title: "Enable iCloud Sync") {
                            Toggle("", isOn: $viewModel.enableCloudSync)
                                .labelsHidden()
                        }
                        SettingsRow(title: "Sync Card Themes Across Devices") {
                            Toggle("", isOn: $viewModel.syncCardThemes)
                                .labelsHidden()
                        }
                        .disabled(!viewModel.enableCloudSync)
                        .opacity(viewModel.enableCloudSync ? 1 : 0.5)

                        SettingsRow(title: "Sync App Theme Across Devices") {
                            Toggle("", isOn: $viewModel.syncAppTheme)
                                .labelsHidden()
                        }
                        .disabled(!viewModel.enableCloudSync)
                        .opacity(viewModel.enableCloudSync ? 1 : 0.5)
                        SettingsRow(title: "Sync Budget Period Across Devices") {
                            Toggle("", isOn: $viewModel.syncBudgetPeriod)
                                .labelsHidden()
                        }
                        .disabled(!viewModel.enableCloudSync)
                        .opacity(viewModel.enableCloudSync ? 1 : 0.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

//                // MARK: Calendar Card
//                SettingsCard(
//                    iconSystemName: "calendar",
//                    title: "Calendar",
//                    subtitle: "Choose how your income calendar is presented."
//                ) {
//                    VStack(spacing: 0) {
//                        SettingsRow(title: "Horizontal Scrolling") {
//                            Toggle("", isOn: $viewModel.calendarHorizontal)
//                                .labelsHidden()
//                        }
//                    }
//                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//                }

                // MARK: Presets Card
                SettingsCard(
                    iconSystemName: "list.bullet.rectangle",
                    title: "Presets",
                    subtitle: "Planned Expenses default to being created as a Preset Planned Expense."
                ) {
                    VStack(spacing: 0) {
                        SettingsRow(title: "Use in Future Budgets by Default") {
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
                            SettingsRow(title: "Manage Categories", detail: "Open") {
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
                            SettingsRow(title: "View Help", detail: "Open") {
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
                            SettingsRow(title: "Repeat Onboarding Process") { EmptyView() }
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
                            SettingsRow(title: "Erase All Data") { EmptyView() }
                        }
                        .buttonStyle(.plain)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ub_glassBackground(
            themeManager.selectedTheme.background,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
        .accentColor(themeManager.selectedTheme.tint)
        .tint(themeManager.selectedTheme.tint)
        .navigationTitle("Settings")
        .alert("Erase All Data?", isPresented: $showResetAlert) {
            Button("Erase", role: .destructive) {
                try? CoreDataService.shared.wipeAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all budgets, cards, incomes, and expenses. This action cannot be undone.")
        }
    }

    // MARK: - Helpers

    /// Balanced padding across platforms; a little more breathing room on larger screens.
    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 24
        #else
        return horizontalSizeClass == .regular ? 24 : 16
        #endif
    }

}

// MARK: - LiquidGlassCustomizationControls
private struct LiquidGlassCustomizationControls: View {
    @EnvironmentObject private var themeManager: ThemeManager

    private var liquidBinding: Binding<Double> {
        Binding(
            get: { themeManager.liquidGlassCustomization.liquidAmount },
            set: { themeManager.updateLiquidGlass(liquidAmount: $0) }
        )
    }

    private var glassBinding: Binding<Double> {
        Binding(
            get: { themeManager.liquidGlassCustomization.glassDepth },
            set: { themeManager.updateLiquidGlass(glassDepth: $0) }
        )
    }

    private var liquidDisplay: String {
        themeManager.liquidGlassCustomization.liquidAmount
            .formatted(.percent.precision(.fractionLength(0)))
    }

    private var glassDisplay: String {
        themeManager.liquidGlassCustomization.glassDepth
            .formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        Group {
            SettingsRow(title: "Liquid Intensity", detail: liquidDisplay) {
                Slider(value: liquidBinding, in: 0...1, step: 0.01) {
                    Text("Liquid Intensity")
                }
                .labelsHidden()
                .frame(minWidth: 160, maxWidth: 220)
            }

            SettingsRow(title: "Glass Depth", detail: glassDisplay) {
                Slider(value: glassBinding, in: 0...1, step: 0.01) {
                    Text("Glass Depth")
                }
                .labelsHidden()
                .frame(minWidth: 160, maxWidth: 220)
            }
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
