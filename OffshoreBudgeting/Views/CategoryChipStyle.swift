import SwiftUI

struct CategoryChipStyle {
    struct Stroke {
        let color: Color
        let lineWidth: CGFloat
    }

    let scale: CGFloat
    let fallbackTextColor: Color
    let fallbackFill: Color
    let fallbackStroke: Stroke
    let glassTextColor: Color
    let glassStroke: Stroke?
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    static func make(
        isSelected: Bool,
        categoryColor: Color,
        colorScheme: ColorScheme
    ) -> CategoryChipStyle {
        if isSelected {
            let strokeColor = categoryColor

            return CategoryChipStyle(
                scale: 1.0,
                fallbackTextColor: .primary,
                fallbackFill: .clear,
                fallbackStroke: Stroke(color: strokeColor, lineWidth: 2),
                glassTextColor: .primary,
                glassStroke: Stroke(color: strokeColor, lineWidth: 2),
                shadowColor: .clear,
                shadowRadius: 0,
                shadowY: 0
            )
        } else {
            return CategoryChipStyle(
                scale: 1.0,
                fallbackTextColor: .primary,
                fallbackFill: DS.Colors.chipFill,
                fallbackStroke: Stroke(color: DS.Colors.chipFill, lineWidth: 1),
                glassTextColor: .primary,
                glassStroke: nil,
                shadowColor: .clear,
                shadowRadius: 0,
                shadowY: 0
            )
        }
    }
}
