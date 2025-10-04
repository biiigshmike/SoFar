//
//  CategoryTotalsRow.swift
//  SoFar
//
//  Shared horizontal chip row displaying spending per category.
//
import SwiftUI

// MARK: - CategoryChipPill
struct CategoryChipPill<Label: View>: View {

    struct Stroke {
        let color: Color
        let lineWidth: CGFloat
    }

    let isSelected: Bool
    let selectionColor: Color?
    let glassStroke: Stroke?
    let fallbackFill: Color
    let fallbackStroke: Stroke?
    private let labelBuilder: () -> Label

    init(
        isSelected: Bool,
        selectionColor: Color?,
        glassStroke: Stroke? = nil,
        fallbackFill: Color = DS.Colors.chipFill,
        fallbackStroke: Stroke? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.selectionColor = selectionColor
        self.glassStroke = glassStroke
        self.fallbackFill = fallbackFill
        self.fallbackStroke = fallbackStroke
        self.labelBuilder = label
    }

    @Environment(\.platformCapabilities) private var capabilities

    private let controlHeight: CGFloat = 44

    private var capsule: Capsule { Capsule(style: .continuous) }

    var body: some View {
        let content = labelBuilder()
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: controlHeight)

        Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                content
                    .glassEffect(.regular, in: capsule)
                    .overlay {
                        if let stroke = glassStroke {
                            capsule.strokeBorder(stroke.color, lineWidth: stroke.lineWidth)
                        }
                    }
            } else {
                content
                    .background {
                        capsule.fill(fallbackFill)
                    }
                    .overlay {
                        if let stroke = fallbackStroke {
                            capsule.strokeBorder(stroke.color, lineWidth: stroke.lineWidth)
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
    @Namespace private var glassNamespace

    var body: some View {
        Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                GlassEffectContainer(spacing: DS.Spacing.s) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DS.Spacing.s) {
                            ForEach(categories) { category in
                                CategoryChipPill(
                                    isSelected: false,
                                    selectionColor: nil
                                ) {
                                    pillLabel(for: category)
                                }
                                .glassEffectID(String(describing: category.id), in: glassNamespace)
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
                        ForEach(categories) { category in
                            CategoryChipPill(
                                isSelected: false,
                                selectionColor: nil
                            ) {
                                pillLabel(for: category)
                            }
                        }
                    }
                    .padding(.horizontal, horizontalInset)
                }
            }
        }
        .ub_hideScrollIndicators()
        .frame(height: controlHeight)
        .opacity(isPlaceholder ? 0 : 1)
        .accessibilityHidden(isPlaceholder)
    }

    // Slightly larger, easier to read, and fills the row visually.
    private var chipFont: Font { .footnote.weight(.semibold) }

    private var chipDotSize: CGFloat { 8 }

    @ViewBuilder
    private func pillLabel(for category: BudgetSummary.CategorySpending) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Circle()
                .fill(Color(hex: category.hexColor ?? "#999999") ?? .secondary)
                .frame(width: chipDotSize, height: chipDotSize)
            Text(category.categoryName)
                .font(chipFont)
            Text(CurrencyFormatterHelper.string(for: category.amount))
                .font(chipFont)
        }
    }
}
