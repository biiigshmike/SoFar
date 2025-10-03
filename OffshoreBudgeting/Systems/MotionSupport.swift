//
//  MotionMonitor.swift
//  SoFar
//
//  Centralized device-motion publisher with smoothing and amplitude scaling.
//  - `roll`, `pitch`, `yaw`, `gravityX/Y/Z`: raw live values (unscaled).
//  - `displayRoll`, `displayPitch`: smoothed + scaled values for UI backgrounds.
//  - `displayGravityX/Y/Z`: smoothed gravity vector for other motion-reactive visuals.
//    Smoothing uses DS.Motion.smoothingAlpha; roll/pitch scaling uses DS.Motion.cardBackgroundAmplitudeScale.
//
//  NOTE: Uses UBMotionsProviding from Compatibility.swift to stay cross-platform.
//

import SwiftUI
import Combine
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

// MARK: - MotionMonitor
@MainActor
final class MotionMonitor: ObservableObject {

    // MARK: Singleton
    static let shared = MotionMonitor()

    // MARK: Raw Motion (unscaled)
    @Published private(set) var roll: Double = 0
    @Published private(set) var pitch: Double = 0
    @Published private(set) var yaw: Double = 0
    @Published private(set) var gravityX: Double = 0
    @Published private(set) var gravityY: Double = 0
    @Published private(set) var gravityZ: Double = 0

    // MARK: Smoothed / Scaled for display (use these for backgrounds)
    @Published private(set) var displayRoll: Double = 0
    @Published private(set) var displayPitch: Double = 0
    @Published private(set) var displayGravityX: Double = 0
    @Published private(set) var displayGravityY: Double = 0
    @Published private(set) var displayGravityZ: Double = 0

    // MARK: Config
    /// Exponential smoothing factor (0 = frozen, 1 = no smoothing).
    private var smoothingAlpha: Double = DS.Motion.smoothingAlpha
    /// Scales raw motion amplitude before smoothing (background sensitivity).
    private var amplitudeScale: Double = DS.Motion.cardBackgroundAmplitudeScale

    // MARK: Provider
    private let provider: UBMotionsProviding
    private var isRunning = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: Init
    init(provider: UBMotionsProviding = UBPlatform.makeMotionProvider()) {
        self.provider = provider
        setupLifecycleObservers()
        start()
    }

    deinit {
        // Intentionally empty: for @MainActor classes, deinit is nonisolated in Swift 6.
        // Avoid calling actor-isolated API here to satisfy isolation rules.
        // Runtime cleanup is handled by lifecycle notifications and weak
        // capture in the provider callback.
    }

    // MARK: start()
    /// Begins motion updates and applies low-pass filtering to `display*`.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        provider.start { [weak self] r, p, y, gx, gy, gz in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.roll = r
                self.pitch = p
                self.yaw = y
                self.gravityX = gx
                self.gravityY = gy
                self.gravityZ = gz

                self.smooth(r, into: &self.displayRoll, scale: self.amplitudeScale)
                self.smooth(p, into: &self.displayPitch, scale: self.amplitudeScale)
                self.smooth(gx, into: &self.displayGravityX)
                self.smooth(gy, into: &self.displayGravityY)
                self.smooth(gz, into: &self.displayGravityZ)
            }
        }
    }

    /// Low-pass filters a raw motion value into its published display counterpart.
    /// - Parameters:
    ///   - raw: Incoming reading from Core Motion.
    ///   - current: Reference to the published display value.
    ///   - scale: Optional amplitude scaling before smoothing.
    private func smooth(_ raw: Double, into current: inout Double, scale: Double = 1.0) {
        let target = raw * scale
        current = current + smoothingAlpha * (target - current)
    }

    // MARK: stop()
    /// Safe to call from ANY context. Hops to the MainActor before stopping updates.
    /// This resolves “Call to main actor-isolated instance method in a nonisolated context”.
    nonisolated func stop() {
        Task { @MainActor in
            guard self.isRunning else { return }
            self.provider.stop()
            self.isRunning = false
        }
    }

    // MARK: updateTuning(smoothing:scale:)
    /// Adjusts smoothing and amplitude scaling at runtime if desired.
    /// - Parameters:
    ///   - smoothing: 0...1 (default from DS.Motion.smoothingAlpha)
    ///   - scale: 0...1 (default from DS.Motion.cardBackgroundAmplitudeScale). Applied to roll/pitch smoothing only.
    func updateTuning(smoothing: Double? = nil, scale: Double? = nil) {
        if let s = smoothing { smoothingAlpha = max(0, min(1, s)) }
        if let k = scale { amplitudeScale = max(0, min(1, k)) }
    }
}

// MARK: - App Lifecycle Integration
private extension MotionMonitor {
    func setupLifecycleObservers() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let center = NotificationCenter.default
        let didEnterBackground = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop() // nonisolated; hops to MainActor internally
        }
        let willEnterForeground = center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            // Hop to MainActor to call the actor-isolated `start()`
            Task { @MainActor [weak self] in self?.start() }
        }
        lifecycleObservers.append(contentsOf: [didEnterBackground, willEnterForeground])
        #endif
    }

    func removeLifecycleObservers() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        let center = NotificationCenter.default
        for token in lifecycleObservers {
            center.removeObserver(token)
        }
        lifecycleObservers.removeAll()
        #endif
    }
}
