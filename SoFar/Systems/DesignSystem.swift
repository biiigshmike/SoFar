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
        /// A dynamic background colour that adapts to light/dark mode on each platform.
        /// On iOS/tvOS this is `secondarySystemBackground`; on macOS it maps to
        /// `underPageBackgroundColor` (fallback to `windowBackgroundColor` on older targets).
        static var containerBackground: Color {
            #if os(iOS) || os(tvOS)
            return Color(UIColor.secondarySystemBackground)
            #elseif os(macOS)
            if #available(macOS 12.0, *) {
                return Color(nsColor: NSColor.underPageBackgroundColor)
            } else {
                return Color(nsColor: NSColor.windowBackgroundColor)
            }
            #else
            return Color.gray.opacity(0.12)
            #endif
        }
    }
}

// Maintain compatibility with existing views using `DS`
typealias DS = DesignSystem

// MARK: - View Helpers
extension View {
    /// Applies the standard background colour to the entire screen.
    /// - Note: New views should call this on their root container to ensure
    /// a consistent background across the app.
    func screenBackground() -> some View {
        self
            .background(DS.Colors.containerBackground)
            .ignoresSafeArea()
    }

    /// Adds the app’s standard “card” background: subtle fill, rounded corners, and soft shadow.
    func cardBackground() -> some View {
        self
            .background(DS.Colors.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .shadow(color: .black.opacity(DS.Shadow.card.opacity),
                    radius: DS.Shadow.card.radius,
                    x: 0,
                    y: DS.Shadow.card.y)
    }
}
