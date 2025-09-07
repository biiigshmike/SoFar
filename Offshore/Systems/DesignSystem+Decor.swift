//
//  DesignSystem+Decor.swift
//  SoFar
//
//  Metallic gradient helpers used by holographic text overlays.
//  These replace the old `UBDecor` functions from your previous project.
//

import SwiftUI

// MARK: - DS.Decor
extension DesignSystem {
    enum Decor {

        // MARK: metallicSilverLinear(angle:)
        /// Broad metallic sweep: multiple stops of white/gray that read as brushed silver.
        /// - Parameter angle: Orientation of the sweep; typically driven by device tilt.
        /// - Returns: A gradient shape style suitable for `.fill(...)`.
        static func metallicSilverLinear(angle: Angle) -> some ShapeStyle {
            AngularGradient(
                gradient: Gradient(colors: [
                    .white.opacity(0.95),
                    .gray.opacity(0.55),
                    .white.opacity(0.90),
                    .gray.opacity(0.50),
                    .white.opacity(0.92)
                ]),
                center: .center,
                angle: angle
            )
        }

        // MARK: metallicShine(angle:intensity:)
        /// Narrow moving shine band. Intensity controls the center highlight strength.
        /// - Parameters:
        ///   - angle: Orientation of the band.
        ///   - intensity: 0...1; increases the center brightness.
        /// - Returns: A gradient shape style suitable for `.fill(...)`.
        static func metallicShine(angle: Angle, intensity: Double) -> some ShapeStyle {
            // The band is mostly transparent with a bright core.
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.36),
                    .init(color: .white.opacity(0.6 + 0.35 * intensity), location: 0.50),
                    .init(color: .clear, location: 0.64)
                ]),
                center: .center,
                angle: angle
            )
        }
    }
}
