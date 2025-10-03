//
//  HolographicMetallicText.swift
//  SoFar
//
//  Metallic text effect that reacts to device tilt using MotionMonitor.
//  Matches the previous project's design: dark readable base text,
//  plus a masked metallic sweep + a narrower moving shine band.
//  On macOS, overlays are disabled and the base text stays legible.
//
//  Usage:
//  HolographicMetallicText(text: "Apple Card")
//      .lineLimit(1)
//      .minimumScaleFactor(0.8)
//

import SwiftUI

// MARK: - HolographicMetallicText
/// Draws a shiny, metallic label. The specular highlight moves with device motion using the smoothed gravity vector.
/// - Parameters:
///   - text: String displayed.
///   - titleFont: Text font. Defaults to rounded, bold 28.
///   - shimmerResponsiveness: Multiplier for how quickly opacity responds to motion (0.0–2.0).
///   - maxMetallicOpacity: Cap for the broad metallic sweep (0.0–1.0).
///   - maxShineOpacity: Cap for the narrow moving shine (0.0–1.0).
@MainActor
struct HolographicMetallicText: View {
    // MARK: Inputs
    let text: String
    var titleFont: Font = Font.system(.title, design: .rounded).weight(.semibold)
    var shimmerResponsiveness: Double = 1.5
    var maxMetallicOpacity: Double = 0.6
    var maxShineOpacity: Double = 0.7

    // MARK: Motion
    /// Use the shared MotionMonitor on the main actor (no default arg needed).
    @ObservedObject private var motion: MotionMonitor = MotionMonitor.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Body
    var body: some View {
        // MARK: Base title (dark + readable across platforms)
        let titleView =
            Text(text)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(UBTypography.cardTitleStatic) // uses your Compatibility.swift
                .ub_cardTitleShadow()

        // MARK: Overlays (masked to text)
        // 1) a broad metallic silver gradient masked to the text
        // 2) a narrower moving shine band, also masked to the text
        titleView
            // Metallic sweep overlay
            .overlay(
                Rectangle()
                    .fill(UBDecor.metallicSilverLinear(angle: metallicAngle))
                    .mask(titleView)
                    .opacity(metallicOpacity)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: metallicOpacity),
                alignment: .center
            )
            // Moving shine overlay
            .overlay(
                Rectangle()
                    .fill(UBDecor.metallicShine(angle: shineAngle, intensity: shineIntensity))
                    .mask(titleView)
                    .opacity(shineOpacity)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: shineOpacity),
                alignment: .center
            )
    }
}

// MARK: - Motion → Parameters
private extension HolographicMetallicText {

    struct GravitySample {
        let x: Double
        let y: Double
        let z: Double
    }

    /// Smoothed, normalized device gravity vector supplied by MotionMonitor.
    var gravitySample: GravitySample {
        GravitySample(
            x: motion.displayGravityX,
            y: motion.displayGravityY,
            z: motion.displayGravityZ
        )
    }

    var horizontalMagnitude: Double {
        let g = gravitySample
        let magnitude = sqrt(g.x * g.x + g.y * g.y)
        return min(1.0, max(0.0, magnitude))
    }

    var faceUpAttenuation: Double {
        let absZ = min(1.0, max(0.0, abs(gravitySample.z)))
        let faceUpStart: Double = 0.9
        let faceUpEnd: Double = 0.98
        if absZ <= faceUpStart { return 1.0 }
        if absZ >= faceUpEnd { return 0.0 }
        let progress = (absZ - faceUpStart) / (faceUpEnd - faceUpStart)
        return max(0.0, min(1.0, 1.0 - progress))
    }

    var gravityDrivenMagnitude: Double {
        let base = horizontalMagnitude
        guard base >= 0.02 else { return 0 }
        return base * faceUpAttenuation
    }

    /// Angle (in degrees) of the horizontal gravity projection; rotates with yaw.
    var horizontalAngleDegrees: Double? {
        guard gravityDrivenMagnitude > 0 else { return nil }
        let g = gravitySample
        return atan2(g.y, g.x) * 180.0 / .pi
    }

    /// Fraction of tilt that is not face-up/down; keeps highlights lively when upright.
    var verticalResponse: Double {
        let absZ = min(1.0, max(0.0, abs(gravitySample.z)))
        return 1.0 - absZ
    }

    /// Magnitude of motion used to drive opacities/intensity.
    /// Based on the horizontal gravity component with face-up damping.
    var motionMagnitude: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        guard !reduceMotion else { return 0 }
        return gravityDrivenMagnitude
        #else
        return 0
        #endif
    }

    // MARK: Metallic Overlay Opacity
    /// A gentle opacity for the broad metallic sweep; scales with motion.
    var metallicOpacity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let magnitude = motionMagnitude
        guard magnitude > 0 else { return 0 }
        let scaled = min(maxMetallicOpacity, max(0.0, magnitude * shimmerResponsiveness))
        return scaled
        #else
        return 0
        #endif
    }

    // MARK: Shine Overlay Opacity
    /// Opacity for the narrower moving shine band; also motion-driven.
    var shineOpacity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let magnitude = motionMagnitude
        guard magnitude > 0 else { return 0 }
        let scaled = min(maxShineOpacity, max(0.0, magnitude * (shimmerResponsiveness + 0.5)))
        return scaled
        #else
        return 0
        #endif
    }

    // MARK: Shine Intensity
    /// Shine intensity adjusts the sharpness/brightness of the center band.
    var shineIntensity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        guard !reduceMotion else { return 0 }
        let base = motionMagnitude * (shimmerResponsiveness + 0.3)
        let boosted = base + verticalResponse * 0.35
        return min(1.0, max(0.0, boosted))
        #else
        return 0
        #endif
    }

    // MARK: Metallic Angle
    /// Follows the smoothed gravity vector. +90° keeps the sweep perpendicular to the tilt direction.
    var metallicAngle: Angle {
        #if os(iOS) || targetEnvironment(macCatalyst)
        guard let baseAngle = horizontalAngleDegrees, !reduceMotion else { return .degrees(0) }
        return .degrees(baseAngle + 90.0)
        #else
        return .degrees(0)
        #endif
    }

    // MARK: Shine Angle
    /// Slightly offset from the gravity-driven metallic angle for a richer specular feel.
    var shineAngle: Angle {
        #if os(iOS) || targetEnvironment(macCatalyst)
        guard let baseAngle = horizontalAngleDegrees, !reduceMotion else { return .degrees(0) }
        return .degrees(baseAngle + 60.0)
        #else
        return .degrees(0)
        #endif
    }
}
