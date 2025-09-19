//
//  DesignSystem.swift
//  SoFar
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI
// MARK: Platform Color Imports
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - DesignSystem (Tokens)
/// Centralized design tokens and tiny helpers for spacing, radius, shadows, and colors.
/// SwiftUI-only types for cross-platform friendliness (iOS, iPadOS, macOS).
enum DesignSystem {

    // MARK: Spacing (pts)
    enum Spacing {
        static let xs: CGFloat = 6
        static let s:  CGFloat = 8
        static let m:  CGFloat = 12
        static let l:  CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner Radii
    enum Radius {
        static let card: CGFloat = 16
        static let chip: CGFloat = 12
    }

    // MARK: Shadows
    enum Shadow {
        static let card = ShadowStyle(radius: 10, y: 4, opacity: 0.08)
    }

    /// Lightweight shadow value object.
    struct ShadowStyle {
        let radius: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    // MARK: Colors
    enum Colors {
        // Accent hues
        static let plannedIncome  = Color.orange
        static let actualIncome   = Color.blue
        static let savingsGood    = Color.green
        static let savingsBad     = Color.red

        // Neutrals
        static let metricLabel    = Color.secondary
        static let cardFill       = Color.gray.opacity(0.08)

        // MARK: System‑Aware Container Background
        /// A dynamic background color that adapts to light/dark mode on each platform.
        /// On iOS/tvOS this is `secondarySystemBackground`; on macOS it maps to
        /// `underPageBackgroundColor` (fallback to `windowBackgroundColor` on older targets).
        static var containerBackground: Color {
            #if os(iOS) || os(tvOS)
            return Color(UIColor.clear)
            #elseif os(macOS)
            if #available(macOS 12.0, *) {
                return Color(nsColor: NSColor.clear)
            } else {
                return Color(nsColor: NSColor.clear)
            }
            #else
            return Color.gray.opacity(0.12)
            #endif
        }

        // MARK: Chip and Pill Fills
        /// Default fill color for unselected category chips and pills.  This neutral
        /// tone ensures that chips sit comfortably on top of the form’s grouped
        /// background on all platforms.  Increase or decrease the opacity to tune
        /// the visual weight of chips globally.
        static var chipFill: Color {
            // Match the card fill opacity for consistency; adjust as desired
            return Color.primary.opacity(0.06)
        }

        /// Fill color for selected category chips and pills.  This uses a slightly
        /// higher opacity of the primary color to indicate selection without
        /// overpowering the interface.  If you wish to refine the selection
        /// contrast across themes, update this constant instead of hardcoding
        /// values in your views.
        static var chipSelectedFill: Color {
            return Color.primary.opacity(0.12)
        }

        /// Stroke color for the selection outline around a chip or pill.  Using
        /// a separate constant allows you to globally adjust the stroke strength
        /// independent of the fill opacity.  When unselected, you may choose to
        /// return `.clear` or a low‑opacity stroke for subtle definition.
        static var chipSelectedStroke: Color {
            return Color.primary.opacity(0.35)
        }
    }
}

// Maintain compatibility with existing views using `DS`
typealias DS = DesignSystem

// MARK: - View Helpers
extension View {
    /// Adds the app’s standard “card” background: subtle fill, rounded corners, and soft shadow.
    func cardBackground() -> some View {
        modifier(UBCardContainerModifier())
    }
}

// MARK: - Private Modifiers

private struct UBCardContainerModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var platformCapabilities

    @ViewBuilder
    func body(content: Content) -> some View {
        if platformCapabilities.supportsLiquidGlass {
            if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
                content
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.Colors.cardFill.opacity(0.45))
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 6)
            } else {
                legacy(content: content)
            }
        } else {
            legacy(content: content)
        }
    }

    @ViewBuilder
    private func legacy(content: Content) -> some View {
        content
            .background(DS.Colors.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .shadow(color: .black.opacity(DS.Shadow.card.opacity),
                    radius: DS.Shadow.card.radius,
                    x: 0,
                    y: DS.Shadow.card.y)
    }
}
