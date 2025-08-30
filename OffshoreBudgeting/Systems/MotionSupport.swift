//
//  MotionMonitor.swift
//  SoFar
//
//  Centralized device-motion publisher with smoothing and amplitude scaling.
//  - `roll`, `pitch`, `yaw`: raw live values (unscaled).
//  - `displayRoll`, `displayPitch`: smoothed + scaled values for UI backgrounds.
//    These use DS.Motion.smoothingAlpha and DS.Motion.cardBackgroundAmplitudeScale.
//
//  NOTE: Uses UBMotionsProviding from Compatibility.swift to stay cross-platform.
//

import SwiftUI
import Combine

// MARK: - MotionMonitor
@MainActor
final class MotionMonitor: ObservableObject {

    // MARK: Singleton
    static let shared = MotionMonitor()

    // MARK: Raw Motion (unscaled)
    @Published private(set) var roll: Double = 0
    @Published private(set) var pitch: Double = 0
    @Published private(set) var yaw: Double = 0

    // MARK: Smoothed / Scaled for display (use these for backgrounds)
    @Published private(set) var displayRoll: Double = 0
    @Published private(set) var displayPitch: Double = 0

    // MARK: Config
    /// Exponential smoothing factor (0 = frozen, 1 = no smoothing).
    private var smoothingAlpha: Double = DS.Motion.smoothingAlpha
    /// Scales raw motion amplitude before smoothing (background sensitivity).
    private var amplitudeScale: Double = DS.Motion.cardBackgroundAmplitudeScale

    // MARK: Provider
    private let provider: UBMotionsProviding

    // MARK: Init
    init(provider: UBMotionsProviding = UBPlatform.makeMotionProvider()) {
        self.provider = provider
        start()
    }

    deinit { stop() }

    // MARK: start()
    /// Begins motion updates and applies low-pass filtering to `display*`.
    func start() {
        provider.start { [weak self] r, p, y in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.roll = r
                self.pitch = p
                self.yaw = y

                // Scale amplitude down first (gentler background).
                let targetR = r * self.amplitudeScale
                let targetP = p * self.amplitudeScale

                // Exponential smoothing: new = old + α * (target - old)
                self.displayRoll  = self.displayRoll  + self.smoothingAlpha * (targetR - self.displayRoll)
                self.displayPitch = self.displayPitch + self.smoothingAlpha * (targetP - self.displayPitch)
            }
        }
    }

    // MARK: stop()
    /// Safe to call from ANY context. Hops to the MainActor before stopping updates.
    /// This resolves “Call to main actor-isolated instance method in a nonisolated context”.
    nonisolated func stop() {
        Task { @MainActor in
            self.provider.stop()
        }
    }

    // MARK: updateTuning(smoothing:scale:)
    /// Adjusts smoothing and amplitude scaling at runtime if desired.
    /// - Parameters:
    ///   - smoothing: 0...1 (default from DS.Motion.smoothingAlpha)
    ///   - scale: 0...1 (default from DS.Motion.cardBackgroundAmplitudeScale)
    func updateTuning(smoothing: Double? = nil, scale: Double? = nil) {
        if let s = smoothing { smoothingAlpha = max(0, min(1, s)) }
        if let k = scale { amplitudeScale = max(0, min(1, k)) }
    }
}
