//
//  CategoryTotalsRow.swift
//  SoFar
//
//  Shared horizontal chip row displaying spending per category.
//
import SwiftUI

// MARK: - CategoryTotalsRow
/// Horizontally scrolling pills showing spend per category.
struct CategoryTotalsRow: View {
    let categories: [BudgetSummary.CategorySpending]
    var isPlaceholder: Bool = false
    var horizontalInset: CGFloat = DS.Spacing.l
    private let controlHeight: CGFloat = 34

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.s) {
                ForEach(categories) { cat in
                    HStack(spacing: DS.Spacing.s) {
                        Circle()
                            .fill(Color(hex: cat.hexColor ?? "#999999") ?? .secondary)
                            .frame(width: chipDotSize, height: chipDotSize)
                        Text(cat.categoryName)
                            .font(chipFont)
                        Text(CurrencyFormatterHelper.string(for: cat.amount))
                            .font(chipFont)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    .frame(height: controlHeight)
                    .background(
                        Capsule().fill(DS.Colors.chipFill)
                    )
                }
            }
            .padding(.horizontal, horizontalInset)
        }
        .ub_hideScrollIndicators()
        .frame(height: controlHeight)
        .opacity(isPlaceholder ? 0 : 1)
        .accessibilityHidden(isPlaceholder)
    }

    // Slightly larger, easier to read, and fills the row visually.
    private var chipFont: Font { .footnote.weight(.semibold) }

    private var chipVerticalPadding: CGFloat { 0 }

    private var chipDotSize: CGFloat { 8 }
}
