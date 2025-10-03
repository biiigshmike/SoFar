//
//  PresetRowView.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI

// MARK: - PresetRowView
/// Row layout matching the screenshot style:
/// Left column: Name, PLANNED/ACTUAL amounts.
/// Right column: "Assigned Budgets" pill and "NEXT DATE" label + value.
/// Tapping the pill opens the assignment sheet via callback.
struct PresetRowView: View {

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: Inputs
    let item: PresetListItem
    let onAssignTapped: (PlannedExpense) -> Void

    // MARK: Body
    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // MARK: Left Column (Title + Planned/Actual)
            VStack(alignment: .leading, spacing: 10) {
                Text(item.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 32) {
                    LabeledAmountBlock(title: "PLANNED", value: item.plannedCurrency)
                    LabeledAmountBlock(title: "ACTUAL", value: item.actualCurrency)
                }
            }

            Spacer(minLength: 12)

            // MARK: Right Column (Assigned Budgets + Next Date)
            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    onAssignTapped(item.template)
                } label: {
                    AssignedBudgetsBadge(
                        title: "Assigned Budgets",
                        count: item.assignedCount,
                        theme: themeManager.selectedTheme,
                        colorScheme: colorScheme
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Assigned Budgets: \(item.assignedCount)")

                VStack(alignment: .trailing, spacing: 4) {
                    Text("NEXT DATE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(item.nextDateLabel)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }

}

// MARK: - LabeledAmountBlock
/// Small helper for the "PLANNED" / "ACTUAL" blocks.
private struct LabeledAmountBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - AssignedBudgetsBadge
private struct AssignedBudgetsBadge: View {
    let title: String
    let count: Int
    let theme: AppTheme
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(titleColor)

            ZStack {
                Circle()
                    .fill(circleBackgroundColor)

                Text("\(count)")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(circleForegroundColor)
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(badgeBackgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(badgeStrokeColor, lineWidth: 1)
        )
    }

    private var titleColor: Color {
        colorScheme == .dark ? Color.white : theme.resolvedTint
    }

    private var circleBackgroundColor: Color {
        if colorScheme == .dark {
            return theme.background
        } else {
            return .white
        }
    }

    private var circleForegroundColor: Color {
        colorScheme == .dark ? theme.resolvedTint : .black
    }

    private var badgeBackgroundColor: Color {
        theme.resolvedTint.opacity(colorScheme == .dark ? 0.2 : 0.08)
    }

    private var badgeStrokeColor: Color {
        theme.resolvedTint.opacity(colorScheme == .dark ? 0.4 : 0.2)
    }
}
