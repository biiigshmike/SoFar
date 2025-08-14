//
//  Compatibility.swift
//  SoFar
//
//  Cross-platform helpers to keep SwiftUI views tidy by hiding
//  platform/version differences behind neutral modifiers and types.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - View Modifiers (Cross-Platform)

extension View {

    // MARK: ub_noAutoCapsAndCorrection()
    /// Disables auto-capitalization and autocorrection where supported (iOS/iPadOS).
    /// On other platforms this is a no-op, allowing a single code path.
    func ub_noAutoCapsAndCorrection() -> some View {
        #if os(iOS)
        if #available(iOS 15.0, *) {
            return self
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        } else {
            return self.disableAutocorrection(true)
        }
        #else
        return self
        #endif
    }

    // MARK: ub_toolbarTitleInline()
    /// Sets the navigation/toolbar title to inline across platforms.
    /// Uses the best available API per OS version and is a no-op if unavailable.
    func ub_toolbarTitleInline() -> some View {
        #if os(iOS) || os(tvOS)
        if #available(iOS 16.0, tvOS 16.0, *) {
            return self.toolbarTitleDisplayMode(.inline)
        } else {
            return self.navigationBarTitleDisplayMode(.inline)
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            return self.toolbarTitleDisplayMode(.inline)
        } else {
            return self
        }
        #else
        return self
        #endif
    }

    // MARK: ub_cardTitleShadow()
    /// Tight, offset shadow for card titles (small 3D lift). Softer gray tone, not harsh black.
    /// Use on text layers: `.ub_cardTitleShadow()`
    func ub_cardTitleShadow() -> some View {
        #if os(macOS)
        return self.shadow(
            color: UBTypography.cardTitleShadowColor,
            radius: 1.0,
            x: 0,
            y: 1.6
        )
        #else
        return self.shadow(
            color: UBTypography.cardTitleShadowColor,
            radius: 0.8,
            x: 0,
            y: 1.2
        )
        #endif
    }
    
    // MARK: ub_compactDatePickerStyle()
    /// Applies `.compact` date picker style where available (iPhone/iPad), no-op elsewhere.
    func ub_compactDatePickerStyle() -> some View {
        #if os(iOS)
        return self.datePickerStyle(.compact)
        #else
        return self
        #endif
    }
    
    // MARK: ub_decimalKeyboard()
    /// Uses the decimal keyboard on iOS; no-op on macOS so the same view compiles for both.
    func ub_decimalKeyboard() -> some View {
        #if os(iOS)
        return self.keyboardType(.decimalPad)
        #else
        return self
        #endif
    }
}

// MARK: - UBColor (Cross-Platform Neutrals)

/// Central place for neutral system-like colors that work on iOS and macOS.
enum UBColor {
    /// Top neutral for card backgrounds.
    static var cardNeutralTop: Color {
        #if canImport(UIKit)
        return Color(UIColor.secondarySystemBackground) // iOS
        #elseif canImport(AppKit)
        if #available(macOS 11.0, *) {
            return Color(nsColor: NSColor.windowBackgroundColor) // macOS
        } else {
            return Color.gray.opacity(0.16)
        }
        #else
        return Color.gray.opacity(0.16)
        #endif
    }

    /// Bottom neutral for card backgrounds.
    static var cardNeutralBottom: Color {
        #if canImport(UIKit)
        return Color(UIColor.tertiarySystemBackground) // iOS
        #elseif canImport(AppKit)
        if #available(macOS 11.0, *) {
            return Color(nsColor: NSColor.controlBackgroundColor) // macOS
        } else {
            return Color.gray.opacity(0.22)
        }
        #else
        return Color.gray.opacity(0.22)
        #endif
    }
}

// MARK: - UBTypography (Cross-Platform text colors)

/// Typography helpers that adapt per platform.
enum UBTypography {
    /// Static title color for card text (legible dark tone on all platforms).
    static var cardTitleStatic: Color {
        #if canImport(UIKit)
        return Color(UIColor.label).opacity(0.92)              // iOS: dark, dynamic
        #elseif canImport(AppKit)
        if #available(macOS 11.0, *) {
            return Color(nsColor: NSColor.labelColor).opacity(0.88) // macOS: dark, dynamic
        } else {
            return Color.black.opacity(0.85)
        }
        #else
        return Color.black.opacity(0.9)
        #endif
    }

    /// Softer, neutral gray for title shadows (avoids harsh pure black).
    static var cardTitleShadowColor: Color {
        #if os(macOS)
        return Color(.sRGB, red: 0.12, green: 0.14, blue: 0.17, opacity: 0.28)
        #else
        return Color(.sRGB, red: 0.16, green: 0.18, blue: 0.22, opacity: 0.22)
        #endif
    }
}

// MARK: - UBDecor (Reusable decorative styles)

enum UBDecor {

    // MARK: metallicSilverLinear(angle:)
    /// A subtle metallic-silver linear gradient for text.
    /// Angle sets the sweep direction; pass a tilt-driven angle.
    static func metallicSilverLinear(angle: Angle) -> AnyShapeStyle {
        // Enhanced metallic gradient with more realistic shine
        let stops: [Gradient.Stop] = [
            .init(color: Color(white: 0.96), location: 0.00),
            .init(color: Color(white: 0.85), location: 0.25),
            .init(color: Color(white: 0.99), location: 0.50),
            .init(color: Color(white: 0.82), location: 0.75),
            .init(color: Color(white: 0.94), location: 1.00)
        ]
        // Convert angle into start/end unit points so the gradient "rotates".
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

// MARK: - Motion Provider Abstraction

protocol UBMotionsProviding: AnyObject {
    func start(onUpdate: @escaping (_ roll: Double, _ pitch: Double, _ yaw: Double) -> Void)
    func stop()
}

#if os(iOS) || targetEnvironment(macCatalyst)
import CoreMotion

final class UBCoreMotionProvider: UBMotionsProviding {
    private let manager = CMMotionManager()
    private var onUpdate: ((_ r: Double, _ p: Double, _ y: Double) -> Void)?

    func start(onUpdate: @escaping (Double, Double, Double) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        self.onUpdate = onUpdate
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            self.onUpdate?(m.attitude.roll, m.attitude.pitch, m.attitude.yaw)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        onUpdate = nil
    }
}
#else
final class UBNoopMotionProvider: UBMotionsProviding {
    func start(onUpdate: @escaping (Double, Double, Double) -> Void) { /* no-op */ }
    func stop() { /* no-op */ }
}
#endif

// MARK: - Factory
enum UBPlatform {
    static func makeMotionProvider() -> UBMotionsProviding {
        #if os(iOS) || targetEnvironment(macCatalyst)
        return UBCoreMotionProvider()
        #else
        return UBNoopMotionProvider()
        #endif
    }
}
