import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {

    /// Returns a contrasting symbol color for swipe action buttons so icons remain legible
    /// against tinted backgrounds introduced with the OS 26 design language.
    func ub_swipeSymbolColor() -> Color {
        guard let components = colorComponents() else {
            return .white
        }

        let luminance = Color.relativeLuminance(red: components.red, green: components.green, blue: components.blue)
        return luminance > 0.6 ? .black : .white
    }

    // MARK: - Component Extraction

    private func colorComponents() -> (red: Double, green: Double, blue: Double)? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (Double(red), Double(green), Double(blue))
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        return (
            Double(converted.redComponent),
            Double(converted.greenComponent),
            Double(converted.blueComponent)
        )
        #endif

        return nil
    }

    private static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func convert(_ value: Double) -> Double {
            if value <= 0.04045 {
                return value / 12.92
            } else {
                return pow((value + 0.055) / 1.055, 2.4)
            }
        }

        let r = convert(red)
        let g = convert(green)
        let b = convert(blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
