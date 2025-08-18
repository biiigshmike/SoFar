//
//  SettingsViewModel.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI
import Combine

// MARK: - SettingsViewModel
/// Observable settings source of truth. Persists via @AppStorage for simplicity.
/// Properties trigger view updates by sending `objectWillChange` on write.
@MainActor
final class SettingsViewModel: ObservableObject {

    /// When true, show a confirmation dialog before deleting items.
    @AppStorage(AppSettingsKeys.confirmBeforeDelete.rawValue)
    var confirmBeforeDelete: Bool = true { willSet { objectWillChange.send() } }

    /// iOS only; toggle haptics. Hidden on macOS automatically.
    @AppStorage(AppSettingsKeys.enableHaptics.rawValue)
    var enableHaptics: Bool = true { willSet { objectWillChange.send() } }

    /// Controls whether the income calendar presents horizontally.
    @AppStorage(AppSettingsKeys.calendarHorizontal.rawValue)
    var calendarHorizontal: Bool = true { willSet { objectWillChange.send() } }

    /// When adding from Presets, default "Use in future budgets?" to ON.
    @AppStorage(AppSettingsKeys.presetsDefaultUseInFutureBudgets.rawValue)
    var presetsDefaultUseInFutureBudgets: Bool = true { willSet { objectWillChange.send() } }

    /// Sync per-card themes across devices using iCloud.
    @AppStorage(AppSettingsKeys.syncCardThemes.rawValue)
    var syncCardThemes: Bool = true { willSet { objectWillChange.send() } }

    /// Sync the overall app theme selection via iCloud.
    @AppStorage(AppSettingsKeys.syncAppTheme.rawValue)
    var syncAppTheme: Bool = true { willSet { objectWillChange.send() } }

    /// Enable iCloud/CloudKit synchronization for Core Data.
    @AppStorage(AppSettingsKeys.enableCloudSync.rawValue)
    var enableCloudSync: Bool = true { willSet { objectWillChange.send() } }

    /// Convenience for platform-specific UI.
    var shouldShowHapticsRow: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Init
    init() {
        UserDefaults.standard.register(defaults: [
            AppSettingsKeys.confirmBeforeDelete.rawValue: true,
            AppSettingsKeys.enableHaptics.rawValue: true,
            AppSettingsKeys.calendarHorizontal.rawValue: true,
            AppSettingsKeys.presetsDefaultUseInFutureBudgets.rawValue: true,
            AppSettingsKeys.syncCardThemes.rawValue: true,
            AppSettingsKeys.syncAppTheme.rawValue: true,
            AppSettingsKeys.enableCloudSync.rawValue: true
        ])
    }
}

// MARK: - Cross-Platform Colors
/// iOS has `UIColor.secondarySystemBackground/tertiarySystemBackground`; macOS does not.
/// These helpers map to sensible AppKit equivalents so our views compile everywhere.
// MARK: - SettingsIcon
/// Rounded square icon that mimics iOS Settings iconography.
/// - Parameters:
///   - systemName: SFSymbol name (e.g., "gearshape").
///   - tint: Foreground tint; defaults to primary.
struct SettingsIcon: View {
    let systemName: String
    var tint: Color = .primary
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.selectedTheme.secondaryBackground)
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

// MARK: - SettingsCard
/// A card with a header (icon, title, subtitle) and a content area for rows.
/// Use for both the hero card and smaller grouped cards.
/// - Parameters:
///   - iconSystemName: SFSymbol for the header icon.
///   - title: Primary title.
///   - subtitle: Secondary descriptive text; keep concise.
///   - content: Row content; `SettingsRow`, `Toggle`, `NavigationLink`, etc.
struct SettingsCard<Content: View>: View {
    let iconSystemName: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                SettingsIcon(systemName: iconSystemName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3).fontWeight(.semibold)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(themeManager.selectedTheme.secondaryBackground)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(themeManager.selectedTheme.tertiaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - SettingsRow
/// A simple row with a left label and optional trailing content (toggle, value label, chevron).
/// Use to keep card internals consistent.
/// - Parameters:
///   - title: Row label.
///   - detail: Optional trailing text if not using a custom trailing view.
///   - trailing: Optional custom trailing view (e.g., Toggle).
struct SettingsRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    init(title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            trailing
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
                .offset(y: -0.25),
            alignment: .top
        )
    }
}
