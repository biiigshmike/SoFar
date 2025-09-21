//
//  CardTheme.swift
//  SoFar
//
//  A small catalog of card themes. Pure SwiftUI Colors (cross-platform).
//

import SwiftUI

// MARK: - Platform Color Bridge
// Uses UIColor on iOS/Catalyst and NSColor on macOS for Canvas CG drawing.
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Helper: labelCGColor(_:)
// Returns a platform-appropriate label color as CGColor with the given alpha.
// - iOS/Catalyst: UIColor.label
// - macOS:        NSColor.labelColor
private func labelCGColor(_ alpha: CGFloat) -> CGColor {
    #if canImport(UIKit)
    return UIColor.label.withAlphaComponent(alpha).cgColor
    #else
    return NSColor.labelColor.withAlphaComponent(alpha).cgColor
    #endif
}

private func rgbaComponents(from color: Color) -> (Double, Double, Double, Double)? {
    #if canImport(UIKit)
    let platformColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    guard platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    return (Double(red), Double(green), Double(blue), Double(alpha))
    #elseif canImport(AppKit)
    let platformColor = NSColor(color)
    let converted = platformColor.usingColorSpace(.deviceRGB)
        ?? platformColor.usingColorSpace(.sRGB)
        ?? platformColor.usingColorSpace(.genericRGB)
    guard let converted else { return nil }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (Double(red), Double(green), Double(blue), Double(alpha))
    #else
    return nil
    #endif
}

// MARK: - CardTheme
/// Palette + behavior for card backgrounds and overlay patterns.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case rose
    case ocean
    case violet
    case graphite
    case mint
    case sunset
    case midnight
    case forest
    case sunrise
    case blossom
    case lavender
    case nebula

    var id: String { rawValue }

    // MARK: Display Name
    var displayName: String {
        switch self {
        case .rose:     return "Rose"
        case .ocean:    return "Ocean"
        case .violet:   return "Violet"
        case .graphite: return "Graphite"
        case .mint:     return "Mint"
        case .sunset:   return "Sunset"
        case .midnight: return "Midnight"
        case .forest:   return "Forest"
        case .sunrise:  return "Sunrise"
        case .blossom:  return "Blossom"
        case .lavender: return "Lavender"
        case .nebula:   return "Nebula"
        }
    }

    // MARK: Base Colors
    /// Two base colors for the background gradient.
    var colors: (Color, Color) {
        switch self {
        case .rose:     return (Color(red: 0.98, green: 0.26, blue: 0.55),
                                Color(red: 0.82, green: 0.00, blue: 0.35))
        case .ocean:    return (Color(red: 0.10, green: 0.66, blue: 0.80),
                                Color(red: 0.02, green: 0.58, blue: 0.74))
        case .violet:   return (Color(red: 0.59, green: 0.37, blue: 0.98),
                                Color(red: 0.46, green: 0.28, blue: 0.90))
        case .graphite: return (Color(red: 0.26, green: 0.28, blue: 0.32),
                                Color(red: 0.17, green: 0.18, blue: 0.20))
        case .mint:     return (Color(red: 0.11, green: 0.83, blue: 0.58),
                                Color(red: 0.06, green: 0.73, blue: 0.51))
        case .sunset:   return (Color(red: 1.00, green: 0.50, blue: 0.15),
                                Color(red: 0.72, green: 0.17, blue: 0.44))
        case .midnight: return (Color(red: 0.08, green: 0.10, blue: 0.26),
                                Color(red: 0.02, green: 0.05, blue: 0.14))
        case .forest:   return (Color(red: 0.13, green: 0.46, blue: 0.30),
                                Color(red: 0.05, green: 0.30, blue: 0.18))
        case .sunrise:  return (Color(red: 1.00, green: 0.76, blue: 0.28),
                                Color(red: 0.99, green: 0.58, blue: 0.20))
        case .blossom:  return (Color(red: 0.99, green: 0.63, blue: 0.81),
                                Color(red: 0.89, green: 0.38, blue: 0.70))
        case .lavender: return (Color(red: 0.78, green: 0.72, blue: 0.98),
                                Color(red: 0.63, green: 0.56, blue: 0.93))
        case .nebula:   return (Color(red: 0.58, green: 0.30, blue: 0.78),
                                Color(red: 0.26, green: 0.09, blue: 0.50))
        }
    }

    // MARK: Stripe Overlay Color (legacy compat)
    /// Kept for backward compatibility where stripes were used.
    var stripeColor: Color {
        switch self {
        case .graphite: return .white.opacity(0.12)
        default:        return .black.opacity(0.12)
        }
    }

    // MARK: Glow Color
    /// Use the leading gradient color as the selection glow.
    var glowColor: Color { colors.0 }

    /// Single flat color used when gradients should be avoided (System theme).
    var flatColor: Color {
        let (top, bottom) = colors
        guard
            let a = rgbaComponents(from: top),
            let b = rgbaComponents(from: bottom)
        else { return top }

        let red = (a.0 + b.0) / 2
        let green = (a.1 + b.1) / 2
        let blue = (a.2 + b.2) / 2
        let alpha = (a.3 + b.3) / 2

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    // MARK: Gradient (tilt-aware)
    /// Returns a background gradient that can subtly rotate with motion.
    /// - Parameters:
    ///   - roll: Device roll in radians.
    ///   - pitch: Device pitch in radians.
    func gradient(roll: Double = 0, pitch: Double = 0) -> LinearGradient {
        let (a, b) = colors
        // Map radians (~-1...1 typical) to small UIPoint deltas
        let dx = CGFloat(max(-0.35, min(0.35, roll))) * 0.5 + 0.5
        let dy = CGFloat(max(-0.35, min(0.35, -pitch))) * 0.5 + 0.5
        let start = UnitPoint(x: 1 - dx, y: dy)
        let end   = UnitPoint(x: dx, y: 1 - dy)
        return LinearGradient(colors: [a, b], startPoint: start, endPoint: end)
    }

    /// Returns a shape style that respects the current app theme preference
    /// for gradients versus flat fills.
    func backgroundStyle(for appTheme: AppTheme) -> AnyShapeStyle {
        if appTheme.usesGlassMaterials {
            return AnyShapeStyle(gradient())
        } else {
            return AnyShapeStyle(flatColor)
        }
    }
}

// MARK: - BackgroundPattern
/// Subtle decorative patterns so each theme gets a different vibe.
private enum BackgroundPattern {
    case diagonalStripes(spacing: CGFloat, thickness: CGFloat, opacity: CGFloat)
    case crossHatch(spacing: CGFloat, thickness: CGFloat, opacity: CGFloat)
    case dots(spacing: CGFloat, diameter: CGFloat, opacity: CGFloat)
    case grid(spacing: CGFloat, thickness: CGFloat, opacity: CGFloat)
    case noise(opacity: CGFloat)
}

// MARK: CardTheme → BackgroundPattern mapping
private extension CardTheme {
    var backgroundPattern: BackgroundPattern {
        switch self {
        case .rose:
            return .crossHatch(spacing: 12, thickness: 1.4, opacity: 0.12)
        case .ocean:
            return .dots(spacing: 12, diameter: 2.6, opacity: 0.12)
        case .violet:
            return .grid(spacing: 14, thickness: 1.0, opacity: 0.10)
        case .graphite:
            return .noise(opacity: 0.08)
        case .mint:
            return .crossHatch(spacing: 16, thickness: 1.2, opacity: 0.10)
        case .sunset:
            return .dots(spacing: 16, diameter: 3.0, opacity: 0.14)
        case .midnight:
            return .noise(opacity: 0.12)
        case .forest:
            return .diagonalStripes(spacing: 14, thickness: 4, opacity: 0.10)
        case .sunrise:
            return .grid(spacing: 12, thickness: 1.0, opacity: 0.12)
        case .blossom:
            return .dots(spacing: 14, diameter: 2.8, opacity: 0.12)
        case .lavender:
            return .crossHatch(spacing: 14, thickness: 1.1, opacity: 0.10)
        case .nebula:
            return .diagonalStripes(spacing: 18, thickness: 5, opacity: 0.12)
        }
    }
}

// MARK: - CardTheme.Pattern Overlay
/// Public entry to draw the pattern for a card background.
extension CardTheme {
    /// Returns a subtle overlay pattern for this theme. Call with `.blendMode(.overlay)` typically.
    /// - Parameter cornerRadius: The card’s corner radius; used for clipping.
    @ViewBuilder
    func patternOverlay(cornerRadius: CGFloat) -> some View {
        switch backgroundPattern {
        case let .diagonalStripes(spacing, thickness, opacity):
            DiagonalStripesOverlay(cornerRadius: cornerRadius, spacing: spacing, thickness: thickness, opacity: opacity)
        case let .crossHatch(spacing, thickness, opacity):
            CrossHatchOverlay(cornerRadius: cornerRadius, spacing: spacing, thickness: thickness, opacity: opacity)
        case let .dots(spacing, diameter, opacity):
            DotsOverlay(cornerRadius: cornerRadius, spacing: spacing, diameter: diameter, opacity: opacity)
        case let .grid(spacing, thickness, opacity):
            GridOverlay(cornerRadius: cornerRadius, spacing: spacing, thickness: thickness, opacity: opacity)
        case let .noise(opacity):
            NoiseOverlay(cornerRadius: cornerRadius, opacity: opacity)
        }
    }
}

// MARK: - Pattern Implementations (SwiftUI-only; iOS/macOS)

// MARK: DiagonalStripesOverlay
private struct DiagonalStripesOverlay: View {
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let thickness: CGFloat
    let opacity: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { ctx, _ in
                ctx.withCGContext { cg in
                    cg.saveGState()
                    let rect = CGRect(origin: .zero, size: size)
                    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    cg.addPath(path); cg.clip()
                    cg.translateBy(x: size.width/2, y: size.height/2)
                    cg.rotate(by: CGFloat(-20.0 * .pi / 180.0))
                    cg.translateBy(x: -size.width/2, y: -size.height/2)
                    let diag = hypot(size.width, size.height)
                    var x = -diag
                    while x < diag {
                        cg.setFillColor(labelCGColor(opacity))
                        cg.fill(CGRect(x: x, y: -diag, width: thickness, height: diag * 3))
                        x += spacing
                    }
                    cg.restoreGState()
                }
            }
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: CrossHatchOverlay
private struct CrossHatchOverlay: View {
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let thickness: CGFloat
    let opacity: CGFloat

    var body: some View {
        ZStack {
            GridOverlay(cornerRadius: cornerRadius, spacing: spacing, thickness: thickness, opacity: opacity)
            GridOverlay(cornerRadius: cornerRadius, spacing: spacing, thickness: thickness, opacity: opacity)
                .rotationEffect(.degrees(45))
                .opacity(0.6)
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: GridOverlay
private struct GridOverlay: View {
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let thickness: CGFloat
    let opacity: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { ctx, _ in
                ctx.withCGContext { cg in
                    cg.saveGState()
                    let rect = CGRect(origin: .zero, size: size)
                    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    cg.addPath(path); cg.clip()
                    let fill = labelCGColor(opacity)
                    // vertical
                    var x: CGFloat = 0
                    while x < size.width {
                        cg.setFillColor(fill)
                        cg.fill(CGRect(x: x, y: 0, width: thickness, height: size.height))
                        x += spacing
                    }
                    // horizontal
                    var y: CGFloat = 0
                    while y < size.height {
                        cg.setFillColor(fill)
                        cg.fill(CGRect(x: 0, y: y, width: size.width, height: thickness))
                        y += spacing
                    }
                    cg.restoreGState()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: DotsOverlay
private struct DotsOverlay: View {
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let diameter: CGFloat
    let opacity: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { ctx, _ in
                ctx.withCGContext { cg in
                    cg.saveGState()
                    let rect = CGRect(origin: .zero, size: size)
                    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    cg.addPath(path); cg.clip()
                    let fill = labelCGColor(opacity)
                    let cols = Int(ceil(size.width / spacing))
                    let rows = Int(ceil(size.height / spacing))
                    for r in 0...rows {
                        for c in 0...cols {
                            let x = CGFloat(c) * spacing
                            let y = CGFloat(r) * spacing
                            let dotRect = CGRect(x: x, y: y, width: diameter, height: diameter)
                            cg.setFillColor(fill)
                            cg.fillEllipse(in: dotRect)
                        }
                    }
                    cg.restoreGState()
                }
            }
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: NoiseOverlay
private struct NoiseOverlay: View {
    let cornerRadius: CGFloat
    let opacity: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(opacity * 0.9), location: 0.05),
                        .init(color: .black.opacity(opacity * 0.6), location: 0.12),
                        .init(color: .clear, location: 0.5),
                        .init(color: .white.opacity(opacity * 0.4), location: 0.75),
                        .init(color: .black.opacity(opacity * 0.4), location: 0.95),
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 450
                )
            )
            .opacity(0.7)
            .allowsHitTesting(false)
    }
}
