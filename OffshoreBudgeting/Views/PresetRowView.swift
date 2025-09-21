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

    // MARK: Environment
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
                        Text("\(item.assignedCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(assignedCountForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(assignedCountBackground)
                            )
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

    // MARK: Private Helpers
    private var assignedCountBackground: Color {
        colorScheme == .dark ? .white : Color.accentColor.opacity(0.15)
    }

    private var assignedCountForeground: Color {
        colorScheme == .dark ? .black : .primary
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
