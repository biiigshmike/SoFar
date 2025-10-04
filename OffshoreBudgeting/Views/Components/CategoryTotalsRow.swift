//
//  CategoryTotalsRow.swift
//  SoFar
//
//  Shared horizontal chip row displaying spending per category.
//
import SwiftUI

// MARK: - CategoryChipPill
struct CategoryChipPill<Label: View>: View {
    let isSelected: Bool
    let selectionColor: Color?
    let glassForeground: Color
    let fallbackForeground: Color
    let fallbackFill: Color
    let fallbackStroke: CategoryChipStyle.Stroke?
    let glassStroke: CategoryChipStyle.Stroke?
    @ViewBuilder var label: () -> Label

    @Environment(\.platformCapabilities) private var capabilities

    init(
        isSelected: Bool,
        selectionColor: Color?,
        glassForeground: Color = .primary,
        fallbackForeground: Color = .primary,
        fallbackFill: Color = DS.Colors.chipFill,
        fallbackStroke: CategoryChipStyle.Stroke? = nil,
        glassStroke: CategoryChipStyle.Stroke? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.selectionColor = selectionColor
        self.glassForeground = glassForeground
        self.fallbackForeground = fallbackForeground
        self.fallbackFill = fallbackFill
        self.fallbackStroke = fallbackStroke
        self.glassStroke = glassStroke
        self.label = label
    }

    var body: some View {
        let capsule = Capsule(style: .continuous)

        let content = label()
            .padding(.horizontal, DS.Spacing.m)
            .frame(height: 44)
            .contentShape(capsule)

        let base = Group {
            if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
                var glass = content
                    .foregroundStyle(glassForeground)
                    .glassEffect(.regular, in: capsule)

                if let stroke = glassStroke {
                    glass = glass.overlay {
                        capsule.strokeBorder(stroke.color, lineWidth: stroke.lineWidth)
                    }
                }

                glass
            } else {
                var fallback = content
                    .foregroundStyle(fallbackForeground)
                    .background {
                        capsule.fill(fallbackFill)
                    }

                if let stroke = fallbackStroke, stroke.lineWidth > 0 {
                    fallback = fallback.overlay {
                        capsule.strokeBorder(stroke.color, lineWidth: stroke.lineWidth)
                    }
                }

                fallback
            }
        }

        return base
            .frame(height: 44)
            .overlay {
                if isSelected {
                    let strokeColor = selectionColor ?? .accentColor
                    capsule.strokeBorder(strokeColor, lineWidth: 2)
                }
            }
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: DS.Spacing.s) {
                            ForEach(categories) { cat in
                                CategoryChipPill(
                                    isSelected: false,
                                    selectionColor: nil
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
                            CategoryChipPill(
                                isSelected: false,
                                selectionColor: nil
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
