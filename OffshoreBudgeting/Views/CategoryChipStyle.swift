import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        let neutralStroke = Stroke(color: DS.Colors.chipFill, lineWidth: 1)

        guard isSelected else {
            return CategoryChipStyle(
                scale: 1.0,
                fallbackTextColor: .primary,
                fallbackFill: DS.Colors.chipFill,
                fallbackStroke: neutralStroke,
                glassTextColor: .primary,
                glassStroke: nil,
                shadowColor: .clear,
                shadowRadius: 0,
                shadowY: 0
            )
        }

        let selectionFill = tintedColor(
            baseNeutral: DS.Colors.chipSelectedFill,
            accent: categoryColor,
            fraction: 0.4,
            colorScheme: colorScheme,
            fallbackOpacity: 0.22
        )

        let selectionStroke = tintedColor(
            baseNeutral: DS.Colors.chipSelectedStroke,
            accent: categoryColor,
            fraction: 0.65,
            colorScheme: colorScheme,
            fallbackOpacity: 0.75
        )

        return CategoryChipStyle(
            scale: 1.0,
            fallbackTextColor: .primary,
            fallbackFill: selectionFill,
            fallbackStroke: Stroke(color: selectionStroke, lineWidth: 1.5),
            glassTextColor: .primary,
            glassStroke: Stroke(color: selectionStroke, lineWidth: 2),
            shadowColor: .clear,
            shadowRadius: 0,
            shadowY: 0
        )
    }
}

// MARK: - Private Helpers

private extension CategoryChipStyle {
    static func tintedColor(
        baseNeutral: Color,
        accent: Color,
        fraction: CGFloat,
        colorScheme: ColorScheme,
        fallbackOpacity: Double
    ) -> Color {
        #if canImport(UIKit)
        let clampedFraction = max(0, min(1, fraction))
        let traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)

        if #available(iOS 14.0, macCatalyst 14.0, *) {
            let baseColor = UIColor(baseNeutral).resolvedColor(with: traitCollection)
            let accentColor = UIColor(accent).resolvedColor(with: traitCollection)

            if let blended = blend(baseColor, with: accentColor, fraction: clampedFraction) {
                return Color(uiColor: blended)
            }
        }
        #endif

        return accent.opacity(fallbackOpacity)
    }

    #if canImport(UIKit)
    private static func blend(
        _ base: UIColor,
        with accent: UIColor,
        fraction: CGFloat
    ) -> UIColor? {
        let t = max(0, min(1, fraction))

        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0

        guard base.getRed(&br, green: &bg, blue: &bb, alpha: &ba),
              accent.getRed(&ar, green: &ag, blue: &ab, alpha: &aa) else {
            return nil
        }

        let r = br + (ar - br) * t
        let g = bg + (ag - bg) * t
        let b = bb + (ab - bb) * t
        let a = ba + (aa - ba) * t

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    #endif
}
