import SwiftUI

struct CategoryChipStyle {
    struct Stroke {
        let color: Color
        let lineWidth: CGFloat
    }

    let scale: CGFloat
    let fallbackTextColor: Color
    let fallbackOverlay: Color?
    let fallbackStroke: Stroke
    let glassTextColor: Color
    let glassStroke: Stroke?
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    static func make(
        isSelected: Bool,
        tint: Color,
        colorScheme: ColorScheme,
        readability: (Color) -> Color
    ) -> CategoryChipStyle {
        if isSelected {
            let overlayOpacity: Double = colorScheme == .dark ? 0.45 : 0.2
            let overlayColor = tint.opacity(overlayOpacity)
            let strokeOpacity: Double = colorScheme == .dark ? 0.9 : 0.65
            let strokeColor = tint.opacity(strokeOpacity)

            return CategoryChipStyle(
                scale: 1.04,
                fallbackTextColor: readability(overlayColor),
                fallbackOverlay: overlayColor,
                fallbackStroke: Stroke(color: strokeColor, lineWidth: 2),
                glassTextColor: readability(tint),
                glassStroke: Stroke(color: strokeColor, lineWidth: 2),
                shadowColor: tint.opacity(colorScheme == .dark ? 0.55 : 0.35),
                shadowRadius: 6,
                shadowY: 3
            )
        } else {
            return CategoryChipStyle(
                scale: 1.0,
                fallbackTextColor: .primary,
                fallbackOverlay: nil,
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
