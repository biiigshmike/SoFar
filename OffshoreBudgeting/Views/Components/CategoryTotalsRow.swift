//
//  CategoryTotalsRow.swift
//  SoFar
//
//  Shared horizontal chip row displaying spending per category.
//
import SwiftUI

// MARK: - CategoryChipPill
struct CategoryChipPill<Label: View>: View {
    private let controlHeight: CGFloat = 44
    private var capsule: Capsule { Capsule(style: .continuous) }

    let isSelected: Bool
    let selectionColor: Color?
    let glassTextColor: Color
    let fallbackTextColor: Color
    let fallbackFill: Color
    let fallbackStrokeColor: Color
    let fallbackStrokeLineWidth: CGFloat
    @ViewBuilder var label: () -> Label

    @Environment(\.platformCapabilities) private var capabilities

    init(
        isSelected: Bool,
        selectionColor: Color? = nil,
        glassTextColor: Color = .primary,
        fallbackTextColor: Color = .primary,
        fallbackFill: Color = DS.Colors.chipFill,
        fallbackStrokeColor: Color = DS.Colors.chipFill,
        fallbackStrokeLineWidth: CGFloat = 1,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.selectionColor = selectionColor
        self.glassTextColor = glassTextColor
        self.fallbackTextColor = fallbackTextColor
        self.fallbackFill = fallbackFill
        self.fallbackStrokeColor = fallbackStrokeColor
        self.fallbackStrokeLineWidth = fallbackStrokeLineWidth
        self.label = label
    }

    var body: some View {
        Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                baseLabel
                    .foregroundStyle(glassTextColor)
                    .glassEffect(.regular, in: capsule)
            } else {
                baseLabel
                    .foregroundStyle(fallbackTextColor)
                    .background {
                        capsule.fill(fallbackFill)
                    }
                    .overlay {
                        if fallbackStrokeLineWidth > 0 {
                            capsule.strokeBorder(
                                fallbackStrokeColor,
                                lineWidth: fallbackStrokeLineWidth
                            )
                        }
                    }
            }
        }
        .overlay {
            if isSelected, let selectionColor {
                capsule.strokeBorder(selectionColor, lineWidth: 2)
            }
        }
        .frame(height: controlHeight)
    }

    private var baseLabel: some View {
        label()
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: controlHeight, alignment: .center)
            .contentShape(capsule)
    }
}

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
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *) {
                GlassEffectContainer(spacing: DS.Spacing.s) {
                    chipScrollContent
                }
            } else {
                chipScrollContent
            }
        }
        .ub_hideScrollIndicators()
        .frame(height: controlHeight)
        .opacity(isPlaceholder ? 0 : 1)
        .accessibilityHidden(isPlaceholder)
    }

    @ViewBuilder
    private var chipScrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.s) {
                ForEach(categories) { cat in
                    let pill = CategoryChipPill(
                        isSelected: false,
                        selectionColor: nil,
                        glassTextColor: .primary,
                        fallbackTextColor: .primary,
                        fallbackFill: DS.Colors.chipFill,
                        fallbackStrokeColor: DS.Colors.chipFill,
                        fallbackStrokeLineWidth: 1
                    ) {
                        HStack(spacing: DS.Spacing.s) {
                            Circle()
                                .fill(Color(hex: cat.hexColor ?? "#999999") ?? .secondary)
                                .frame(width: chipDotSize, height: chipDotSize)
                            Text(cat.categoryName)
                                .font(chipFont)
                            Text(CurrencyFormatterHelper.string(for: cat.amount))
                                .font(chipFont)
                        }
                    }
                    if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                        pill
                            .glassEffectID(String(describing: cat.id), in: glassNamespace)
                            .glassEffectTransition(.matchedGeometry)
                    } else {
                        pill
                    }
                }
            }
            .padding(.horizontal, horizontalInset)
        }
        .allowsHitTesting(isInteractive)
    }

    // Slightly larger, easier to read, and fills the row visually.
    private var chipFont: Font { .footnote.weight(.semibold) }

    private var chipVerticalPadding: CGFloat { 0 }

    private var chipDotSize: CGFloat { 8 }
}
