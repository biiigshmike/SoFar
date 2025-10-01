import SwiftUI

// MARK: - UBTypography (Cross-Platform text colors)

/// Typography helpers used by metallic/holographic text effects and card titles.
enum UBTypography {
    /// Static title color for card text (legible dark tone on all platforms).
    static var cardTitleStatic: Color {
        return Color(UIColor.label).opacity(0.92)
    }

    /// Softer, neutral gray for title shadows (avoids harsh pure black).
    static var cardTitleShadowColor: Color {
        return Color(.sRGB, red: 0.16, green: 0.18, blue: 0.22, opacity: 0.22)
    }
}

// MARK: - UBDecor (Reusable decorative styles)

/// Decorative gradient helpers used by holographic/metallic text overlays.
enum UBDecor {

    // MARK: metallicSilverLinear(angle:)
    /// A subtle metallic-silver linear gradient for text.
    /// Angle sets the sweep direction; pass a tilt-driven angle.
    static func metallicSilverLinear(angle: Angle) -> AnyShapeStyle {
        let stops: [Gradient.Stop] = [
            .init(color: Color(white: 0.96), location: 0.00),
            .init(color: Color(white: 0.85), location: 0.25),
            .init(color: Color(white: 0.99), location: 0.50),
            .init(color: Color(white: 0.82), location: 0.75),
            .init(color: Color(white: 0.94), location: 1.00)
        ]
        let theta = angle.radians
        let dx = cos(theta)
        let dy = sin(theta)
        let start = UnitPoint(x: 0.5 - dx * 0.6, y: 0.5 - dy * 0.6)
        let end   = UnitPoint(x: 0.5 + dx * 0.6, y: 0.5 + dy * 0.6)

        return AnyShapeStyle(
            LinearGradient(gradient: Gradient(stops: stops), startPoint: start, endPoint: end)
        )
    }

    // MARK: holographicGradient(angle:)
    static func holographicGradient(angle: Angle) -> AnyShapeStyle {
        let stops: [Gradient.Stop] = [
            .init(color: Color(red: 0.98, green: 0.78, blue: 0.82), location: 0.0),
            .init(color: Color(red: 0.92, green: 0.81, blue: 0.65), location: 0.15),
            .init(color: Color(red: 0.88, green: 0.92, blue: 0.85), location: 0.3),
            .init(color: Color(red: 0.75, green: 0.89, blue: 0.95), location: 0.45),
            .init(color: Color(red: 0.85, green: 0.78, blue: 0.92), location: 0.6),
            .init(color: Color(red: 0.95, green: 0.78, blue: 0.85), location: 0.75),
            .init(color: Color(red: 0.98, green: 0.85, blue: 0.72), location: 0.9),
            .init(color: Color(red: 0.98, green: 0.78, blue: 0.82), location: 1.0)
        ]
        let theta = angle.radians
        let dx = cos(theta)
        let dy = sin(theta)
        let start = UnitPoint(x: 0.5 - dx * 0.7, y: 0.5 - dy * 0.7)
        let end   = UnitPoint(x: 0.5 + dx * 0.7, y: 0.5 + dy * 0.7)

        return AnyShapeStyle(
            LinearGradient(gradient: Gradient(stops: stops), startPoint: start, endPoint: end)
        )
    }

    // MARK: holographicShine(angle:)
    static func holographicShine(angle: Angle, intensity: Double) -> AnyShapeStyle {
        let stops: [Gradient.Stop] = [
            .init(color: Color(white: 1.0).opacity(0.0), location: 0.0),
            .init(color: Color(white: 0.98).opacity(intensity * 0.4), location: 0.3),
            .init(color: Color(white: 1.0).opacity(intensity * 0.7), location: 0.5),
            .init(color: Color(white: 0.98).opacity(intensity * 0.4), location: 0.7),
            .init(color: Color(white: 1.0).opacity(0.0), location: 1.0)
        ]
        let theta = angle.radians
        let dx = cos(theta) * 0.5
        let dy = sin(theta) * 0.5
        let center = UnitPoint(x: 0.5 + dx, y: 0.5 + dy)

        return AnyShapeStyle(
            RadialGradient(gradient: Gradient(stops: stops), center: center, startRadius: 0, endRadius: 100)
        )
    }

    // MARK: metallicShine(angle:, intensity:)
    static func metallicShine(angle: Angle, intensity: Double) -> AnyShapeStyle {
        let stops: [Gradient.Stop] = [
            .init(color: Color(white: 1.0).opacity(0.0), location: 0.0),
            .init(color: Color(white: 0.98).opacity(intensity * 0.3), location: 0.4),
            .init(color: Color(white: 1.0).opacity(intensity * 0.6), location: 0.5),
            .init(color: Color(white: 0.95).opacity(intensity * 0.3), location: 0.6),
            .init(color: Color(white: 1.0).opacity(0.0), location: 1.0)
        ]
        let theta = angle.radians
        let dx = cos(theta) * 0.6
        let dy = sin(theta) * 0.6
        let center = UnitPoint(x: 0.5 + dx, y: 0.5 + dy)

        return AnyShapeStyle(
            RadialGradient(gradient: Gradient(stops: stops), center: center, startRadius: 0, endRadius: 80)
        )
    }
}

