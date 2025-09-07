//
//  Color+Hex.swift
//  SoFar
//
//  Tiny helper to convert hex strings like "#FFAA00" or "FFAA00" into Color.
//

import SwiftUI

// MARK: - Color + Hex
extension Color {

    // MARK: init?(hex:)
    /// Initializes a Color from a hex string. Supports "#RRGGBB" and "RRGGBB".
    /// - Parameter hex: Hex string (with or without '#').
    init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6,
              let rgb = Int(cleaned, radix: 16) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
