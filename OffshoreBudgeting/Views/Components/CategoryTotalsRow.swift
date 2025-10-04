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
    var isInteractive: Bool = true
    var horizontalInset: CGFloat = DS.Spacing.l
    private let controlHeight: CGFloat = 44
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    @Namespace private var glassNamespace

    var body: some View {
        Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                GlassEffectContainer(spacing: DS.Spacing.s) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DS.Spacing.s) {
                            ForEach(categories) { cat in
                                let capsule = Capsule(style: .continuous)
                                let content = HStack(spacing: DS.Spacing.s) {
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

                                content
                                    .glassEffect(.regular, in: capsule)
                                    .glassEffectID(String(describing: cat.id), in: glassNamespace)
                                    .glassEffectTransition(.matchedGeometry)
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                    }
                    .allowsHitTesting(isInteractive)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DS.Spacing.s) {
                        ForEach(categories) { cat in
                            let content = HStack(spacing: DS.Spacing.s) {
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
                            content
                                .background(
                                    Capsule().fill(DS.Colors.chipFill)
                                )
                        }
                    }
                    .padding(.horizontal, horizontalInset)
                }
//                .allowsHitTesting(isInteractive)
            }
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
