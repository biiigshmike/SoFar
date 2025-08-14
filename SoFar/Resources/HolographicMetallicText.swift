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
/// Draws a shiny, metallic label. The specular highlight moves with device motion.
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
    var titleFont: Font = .system(size: 28, weight: .semibold, design: .rounded)
    var shimmerResponsiveness: Double = 1.5
    var maxMetallicOpacity: Double = 0.6
    var maxShineOpacity: Double = 0.7

    // MARK: Motion
    /// Use the shared MotionMonitor on the main actor (no default arg needed).
    @ObservedObject private var motion: MotionMonitor = MotionMonitor.shared

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
                    .animation(.easeOut(duration: 0.15), value: metallicOpacity),
                alignment: .center
            )
            // Moving shine overlay
            .overlay(
                Rectangle()
                    .fill(UBDecor.metallicShine(angle: shineAngle, intensity: shineIntensity))
                    .mask(titleView)
                    .opacity(shineOpacity)
                    .animation(.easeOut(duration: 0.10), value: shineOpacity),
                alignment: .center
            )
    }
}

// MARK: - Motion → Parameters
private extension HolographicMetallicText {

    /// Magnitude of motion used to drive opacities/intensity.
    var motionMagnitude: Double {
        sqrt(motion.roll * motion.roll + motion.pitch * motion.pitch)
    }

    // MARK: Metallic Overlay Opacity
    /// A gentle opacity for the broad metallic sweep; scales with motion.
    var metallicOpacity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let scaled = min(maxMetallicOpacity, max(0.0, motionMagnitude * shimmerResponsiveness))
        return scaled
        #else
        return 0
        #endif
    }

    // MARK: Shine Overlay Opacity
    /// Opacity for the narrower moving shine band; also motion-driven.
    var shineOpacity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let scaled = min(maxShineOpacity, max(0.0, motionMagnitude * (shimmerResponsiveness + 0.5)))
        return scaled
        #else
        return 0
        #endif
    }

    // MARK: Shine Intensity
    /// Shine intensity adjusts the sharpness/brightness of the center band.
    var shineIntensity: Double {
        #if os(iOS) || targetEnvironment(macCatalyst)
        return min(1.0, max(0.0, motionMagnitude * (shimmerResponsiveness + 0.3)))
        #else
        return 0
        #endif
    }

    // MARK: Metallic Angle
    /// Follows device tilt (roll/pitch). +90° so the sweep is perpendicular to tilt.
    var metallicAngle: Angle {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let angleDeg = atan2(motion.pitch, motion.roll) * 180.0 / .pi + 90.0
        return .degrees(angleDeg)
        #else
        return .degrees(0)
        #endif
    }

    // MARK: Shine Angle
    /// Slightly offset from the metallic angle for a richer specular feel.
    var shineAngle: Angle {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let angleDeg = atan2(motion.pitch, motion.roll) * 180.0 / .pi + 60.0
        return .degrees(angleDeg)
        #else
        return .degrees(0)
        #endif
    }
}
