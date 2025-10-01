//
//  DesignSystem.swift
//  SoFar
//  Created by Michael Brown on 8/8/25.
//

import SwiftUI
// MARK: Platform Color Imports
import UIKit

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
    }

    // MARK: Colors
    enum Colors {
        // Accent hues
        static let plannedIncome  = Color.orange
        static let actualIncome   = Color.blue
        static let savingsGood    = Color.green
        static let savingsBad     = Color.red

        // Neutrals
        static let cardFill       = Color.gray.opacity(0.08)

        // MARK: System‑Aware Container Background
        /// A dynamic background color that adapts to light/dark mode across UIKit platforms.
        static var containerBackground: Color {
            if #available(iOS 13.0, macCatalyst 13.0, *) {
                return Color(UIColor.secondarySystemBackground)
            } else {
                return Color(UIColor(white: 0.92, alpha: 1.0))
            }
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
