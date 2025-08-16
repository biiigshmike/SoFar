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

    @StateObject private var viewModel = SettingsViewModel()

    // MARK: Layout Constants
    private var maxReadableWidth: CGFloat {
        #if os(macOS)
        return 720
        #else
        return 680
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: General Hero Card
                SettingsCard(
                    iconSystemName: "gearshape",
                    title: "General",
                    subtitle: "Manage the app’s behavior, confirmations, and feedback."
                ) {
                    VStack(spacing: 0) {
                        SettingsRow(title: "Confirm Before Deleting") {
                            Toggle("", isOn: $viewModel.confirmBeforeDelete)
                                .labelsHidden()
                        }

                        if viewModel.shouldShowHapticsRow {
                            SettingsRow(title: "Enable Haptics") {
                                Toggle("", isOn: $viewModel.enableHaptics)
                                    .labelsHidden()
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // MARK: Calendar Card
                SettingsCard(
                    iconSystemName: "calendar",
                    title: "Calendar",
                    subtitle: "Choose how your income calendar is presented."
                ) {
                    VStack(spacing: 0) {
                        SettingsRow(title: "Horizontal Scrolling") {
                            Toggle("", isOn: $viewModel.calendarHorizontal)
                                .labelsHidden()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // MARK: Presets Card
                SettingsCard(
                    iconSystemName: "list.bullet.rectangle",
                    title: "Presets",
                    subtitle: "Defaults applied when adding from Presets."
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
                    subtitle: "Create, rename, reorder, and color your categories."
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

            }
            .frame(maxWidth: maxReadableWidth)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(groupedBackground.ignoresSafeArea())
        .screenBackground()
        .navigationTitle("Settings")
        // Use inline title on iOS; do nothing on macOS to avoid the availability error.
        .applyInlineNavTitleOnIOS()
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

    /// Matches iOS grouped background feel on all platforms.
    private var groupedBackground: Color {
        #if os(macOS)
        return Color(nsColor: .clear)
        #else
        return Color(.systemGroupedBackground)
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
