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
        modifier(UBDecimalKeyboardModifier())
    }

    /// Applies the platform-aware Liquid Glass background when supported,
    /// falling back to the provided base color elsewhere.
    /// - Parameters:
    ///   - baseColor: The theme/tint-aware fallback color.
    ///   - edges: Optional edges that should extend through the safe area.
    func ub_glassBackground(
        _ baseColor: Color,
        configuration: AppTheme.GlassConfiguration = .standard,
        ignoringSafeArea edges: Edge.Set = []
    ) -> some View {
        modifier(
            UBGlassBackgroundModifier(
                baseColor: baseColor,
                configuration: configuration,
                ignoresSafeAreaEdges: edges
            )
        )
    }

    /// Applies a translucent navigation bar treatment that mirrors the
    /// Liquid Glass surface configuration when supported by the platform.
    /// Uses the provided base color and configuration to build a subtle
    /// gradient wash that picks up the current theme's accent tint.
    func ub_navigationGlassBackground(
        baseColor: Color,
        configuration: AppTheme.GlassConfiguration
    ) -> some View {
        modifier(
            UBNavigationGlassModifier(
                baseColor: baseColor,
                configuration: configuration
            )
        )
    }

    // MARK: ub_formStyleGrouped()
    /// Applies a grouped form style on platforms that support it.  On iOS 16+
    /// and macOS 13+, `.formStyle(.grouped)` gives a subtle, neutral
    /// background with inset sections.  On older systems or platforms that
    /// don’t support it, this is a no-op so the view still compiles.  Use
    /// this helper instead of sprinkling `#if` checks throughout your views.
    func ub_formStyleGrouped() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            return self.formStyle(.grouped)
        } else {
            return self
        }
    }

    // MARK: ub_sheetPadding()
    /// Adds a subtle inner padding around sheet content on macOS.  On other
    /// platforms this returns `self` unchanged.  Use this at the end of your
    /// sheet view chain to avoid flush edges on macOS sheets without
    /// duplicating `#if os(macOS)` in every view.
    func ub_sheetPadding() -> some View {
        #if os(macOS)
        return self
            .padding(.horizontal, 16)
            .padding(.top, 8)
        #else
        return self
        #endif
    }

    // MARK: ub_pickerBackground()
    /// Applies the app’s container background behind a scrollable picker (e.g.
    /// card or budget pickers).  Without a background, horizontal `ScrollView`s
    /// in a form may render on pure white on macOS and grouped gray on iOS.
    /// Applying this ensures consistency across platforms.  You can call
    /// `.ub_pickerBackground()` on a `ScrollView` or any container view to
    /// unify its background.
    func ub_pickerBackground() -> some View {
        self.background(DS.Colors.containerBackground)
    }

    // MARK: ub_hideScrollIndicators()
    /// Hides scroll indicators consistently across platforms.  On iOS and
    /// macOS this sets `.scrollIndicators(.hidden)` when available; on older
    /// versions it falls back to the legacy API.  Use this to avoid
    /// repetitive availability checks.
    func ub_hideScrollIndicators() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            return self.scrollIndicators(.hidden)
        } else {
            return self
        }
    }
}

// MARK: - Private Modifiers

private struct UBDecimalKeyboardModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var platformCapabilities

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if platformCapabilities.supportsAdaptiveKeypad {
            if #available(iOS 18.0, *) {
                content
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
            } else {
                content.keyboardType(.decimalPad)
            }
        } else {
            content.keyboardType(.decimalPad)
        }
        #else
        content
        #endif
    }
}

private struct UBGlassBackgroundModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var platformCapabilities

    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration
    let ignoresSafeAreaEdges: Edge.Set

    func body(content: Content) -> some View {
        content.background(
            UBGlassBackgroundView(
                capabilities: platformCapabilities,
                baseColor: baseColor,
                configuration: configuration,
                ignoresSafeAreaEdges: ignoresSafeAreaEdges
            )
        )
    }
}

private struct UBNavigationGlassModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if capabilities.supportsLiquidGlass {
            if #available(iOS 16.0, *) {
                content
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(configuration.glass.material.shapeStyle, for: .navigationBar)
                    .toolbarBackground(gradientStyle, for: .navigationBar)
            } else {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }

    #if os(iOS)
    @available(iOS 16.0, *)
    private var gradientStyle: AnyShapeStyle {
        let highlight = Color.white.opacity(min(configuration.glass.highlightOpacity * 0.6, 0.28))
        let mid = baseColor.opacity(min(configuration.liquid.tintOpacity + 0.12, 0.92))
        let shadow = configuration.glass.shadowColor.opacity(min(configuration.glass.shadowOpacity * 0.85, 0.6))

        return AnyShapeStyle(
            LinearGradient(
                colors: [highlight, mid, shadow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    #endif
}

private struct UBGlassBackgroundView: View {
    let capabilities: PlatformCapabilities
    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration
    let ignoresSafeAreaEdges: Edge.Set

    var body: some View {
        backgroundLayer
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if ignoresSafeAreaEdges.isEmpty {
            baseLayer
        } else {
            baseLayer.ub_ignoreSafeArea(edges: ignoresSafeAreaEdges)
        }
    }

    @ViewBuilder
    private var baseLayer: some View {
        if capabilities.supportsLiquidGlass {
            if #available(iOS 15.0, macOS 13.0, tvOS 15.0, *) {
                #if os(iOS) || os(tvOS) || os(macOS)
                decoratedGlass
                    .background(configuration.glass.material.shapeStyle)
                #else
                decoratedGlass
                #endif
            } else {
                decoratedGlass
            }
        } else {
            decoratedGlass
        }
    }

    private var decoratedGlass: some View {
        ZStack {
            Rectangle()
                .fill(baseColor.opacity(configuration.liquid.tintOpacity))

            if configuration.liquid.bloom > 0 {
                bloomOverlay
            }

            if configuration.glass.shadowOpacity > 0 {
                shadowOverlay
            }

            if configuration.glass.highlightOpacity > 0 {
                highlightOverlay
            }

            if configuration.glass.specularOpacity > 0 {
                specularOverlay
            }

            if configuration.glass.rimOpacity > 0 && configuration.glass.rimWidth > 0 {
                rimOverlay
            }

            if configuration.glass.noiseOpacity > 0 {
                noiseOverlay
            }
        }
        .compositingGroup()
        .saturation(configuration.liquid.saturation)
        .brightness(configuration.liquid.brightness)
        .contrast(configuration.liquid.contrast)
    }

    private var bloomOverlay: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(configuration.liquid.bloom),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
            )
            .blendMode(.screen)
    }

    private var highlightOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        configuration.glass.highlightColor.opacity(configuration.glass.highlightOpacity),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blur(radius: configuration.glass.highlightBlur)
    }

    private var shadowOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        configuration.glass.shadowColor.opacity(configuration.glass.shadowOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blur(radius: configuration.glass.shadowBlur)
    }

    private var specularOverlay: some View {
        let clampedWidth = min(max(configuration.glass.specularWidth, 0.001), 0.49)
        let lower = max(0.0, 0.5 - clampedWidth)
        let upper = min(1.0, 0.5 + clampedWidth)

        return Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: configuration.glass.specularColor.opacity(0.0), location: 0.0),
                        .init(color: configuration.glass.specularColor.opacity(configuration.glass.specularOpacity), location: lower),
                        .init(color: configuration.glass.specularColor.opacity(configuration.glass.specularOpacity), location: upper),
                        .init(color: configuration.glass.specularColor.opacity(0.0), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)
    }

    private var rimOverlay: some View {
        Rectangle()
            .strokeBorder(
                configuration.glass.rimColor.opacity(configuration.glass.rimOpacity),
                lineWidth: configuration.glass.rimWidth
            )
            .blur(radius: configuration.glass.rimBlur)
            .blendMode(.screen)
    }

    private var noiseOverlay: some View {
        Rectangle()
            .fill(Color.white.opacity(configuration.glass.noiseOpacity))
            .blendMode(.softLight)
    }
}

private extension Edge.Set {
    var isEmpty: Bool { self == [] }
}

private extension View {
    @ViewBuilder
    func ub_ignoreSafeArea(edges: Edge.Set) -> some View {
        #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.ignoresSafeArea(.container, edges: edges)
        } else {
            self.edgesIgnoringSafeArea(edges)
        }
        #else
        self
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
            let window = NSColor.windowBackgroundColor.ub_convertedToWorkingSpace()
            let lifted = window.ub_blend(with: .white, amount: 0.32)
            let accent = NSColor.controlAccentColor.withAlphaComponent(0.35)
            let tinted = lifted.ub_blend(with: accent, amount: 0.08)
            return Color(nsColor: tinted) // macOS
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
            let control = NSColor.controlBackgroundColor.ub_convertedToWorkingSpace()
            let elevated = control.ub_blend(with: .white, amount: 0.26)
            let accent = NSColor.controlAccentColor.withAlphaComponent(0.28)
            let tinted = elevated.ub_blend(with: accent, amount: 0.1)
            return Color(nsColor: tinted) // macOS
        } else {
            return Color.gray.opacity(0.22)
        }
        #else
        return Color.gray.opacity(0.22)
        #endif
    }
}

#if canImport(AppKit)
private extension NSColor {
    func ub_convertedToWorkingSpace() -> NSColor {
        usingColorSpace(.displayP3) ?? usingColorSpace(.deviceRGB) ?? self
    }

    func ub_blend(with color: NSColor, amount: CGFloat) -> NSColor {
        let clamped = max(0, min(1, amount))
        let base = ub_convertedToWorkingSpace()
        let target = color.ub_convertedToWorkingSpace()
        return base.blended(withFraction: clamped, of: target) ?? base
    }
}
#endif

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

// MARK: - Global Helpers

/// Dismisses the on‑screen keyboard on platforms that support UIKit.
/// Call this in your save actions to neatly resign the first responder before
/// dismissing a sheet.  On macOS and other platforms this is a no‑op.
func ub_dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
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
