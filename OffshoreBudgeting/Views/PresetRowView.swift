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
                    HStack(spacing: 8) {
                        Text("Assigned Budgets")
                            .foregroundStyle(.primary)
                        Text("\(item.assignedCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(assignedBudgetsCountColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(assignedBudgetsBackground))
                    }
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

    private var assignedBudgetsCountColor: Color {
        colorScheme == .dark ? .black : Color.primary
    }

    private var assignedBudgetsBackground: Color {
        colorScheme == .dark ? .white : Color.accentColor.opacity(0.15)
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
