//
//  DesignSystem+Typography.swift
//  SoFar
//
//  Typography helpers used by holographic text.
//
//  NOTE: Removed ub_cardTitleShadow() here to avoid a duplicate with Compatibility.swift.
//  Keep the canonical implementation in Compatibility.swift.
//

import SwiftUI

// MARK: - DS.Typography
extension DesignSystem {
    enum Typography {
        // MARK: cardTitleStatic
        /// Optional gradient you can use elsewhere if desired.
        static var cardTitleStatic: LinearGradient {
            LinearGradient(
                colors: [
                    Color(white: 0.15),
                    Color(white: 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
