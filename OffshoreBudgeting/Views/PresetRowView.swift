//
//  PresetRowView.swift
//  SoFar
//
//  Created by Michael Brown on 8/14/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
        VStack(alignment: .leading, spacing: 12) {

            // MARK: Title + Assigned Budgets Badge
            HStack(alignment: .center, spacing: 12) {
                Text(item.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                Button {
                    onAssignTapped(item.template)
                } label: {
                    AssignedBudgetsBadge(
                        title: "Assigned Budgets",
                        count: item.assignedCount,
                        colorScheme: colorScheme
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Assigned Budgets: \(item.assignedCount)")
            }

            // MARK: Amounts + Next Date
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 32) {
                    LabeledAmountBlock(title: "PLANNED", value: item.plannedCurrency)
                    LabeledAmountBlock(title: "ACTUAL", value: item.actualCurrency)
                }

                Spacer(minLength: 12)

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
    }

    private var titleColor: Color {
        .primary
    }

    private var circleBackgroundColor: Color {
        if colorScheme == .dark {
            return circleBackgroundColorDark
        }

        return circleBackgroundColorLight
    }

    private var circleForegroundColor: Color {
        .primary
    }

    private var circleBackgroundColorLight: Color {
#if canImport(UIKit)
        Color(uiColor: .systemGray5)
#elseif canImport(AppKit)
        Color(nsColor: .systemGray5)
#else
        Color.gray.opacity(0.2)
#endif
    }

    private var circleBackgroundColorDark: Color {
#if canImport(UIKit)
        Color(uiColor: .systemGray3)
#elseif canImport(AppKit)
        Color(nsColor: .systemGray3)
#else
        Color.gray.opacity(0.4)
#endif
    }
}
