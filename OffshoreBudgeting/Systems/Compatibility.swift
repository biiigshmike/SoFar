//
//  Compatibility.swift
//  SoFar
//
//  Cross-platform helpers to keep SwiftUI views tidy by hiding
//  platform/version differences behind neutral modifiers and types.
//

import SwiftUI
import UIKit

// MARK: - Glass Background Policy

/// Centralized policy for deciding when the app should render Liquid Glass
/// backgrounds versus classic opaque fills. We rely on the combination of the
/// current theme and the resolved platform capabilities so tests can simulate
/// OS 26 (glass available) and OS 15.4 (opaque) configurations without
/// sprinkling conditional logic across individual modifiers.
struct UBGlassBackgroundPolicy {
    /// Determines whether surface-level backgrounds (root pages, navigation)
    /// should adopt the custom glass treatment. Themes like `.system` opt out
    /// even on modern OS builds to mirror Apple's stock styling.
    static func shouldUseGlassSurfaces(
        theme: AppTheme,
        capabilities: PlatformCapabilities
    ) -> Bool {
        capabilities.supportsOS26Translucency && theme.usesGlassMaterials
    }

    /// Determines whether container chrome (tab bars, navigation bars) should
    /// defer to the system's built-in glass materials. On legacy OS versions we
    /// return `false` so modifiers can fall back to opaque backgrounds that
    /// match the classic design.
    static func shouldUseSystemChrome(capabilities: PlatformCapabilities) -> Bool {
        capabilities.supportsOS26Translucency
    }
}

// MARK: - View Modifiers (Cross-Platform)

extension View {

    // MARK: ub_onChange(of:initial:)
    /// Bridges the macOS 14 / iOS 17 `onChange` overloads with earlier operating systems.
    /// - Parameters:
    ///   - value: The equatable value to observe.
    ///   - initial: Whether the action should fire immediately on appear.
    ///   - action: A closure executed whenever `value` changes.
    /// - Returns: A view that performs the provided action when `value` changes.
    func ub_onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        modifier(
            UBOnChangeWithoutValueModifier(
                value: value,
                initial: initial,
                action: action
            )
        )
    }

    /// Bridges the macOS 14 / iOS 17 `onChange` overloads with earlier operating systems.
    /// Provides the new value back to the caller whenever it changes.
    /// - Parameters:
    ///   - value: The equatable value to observe.
    ///   - initial: Whether the action should fire immediately on appear.
    ///   - action: A closure receiving the new value whenever `value` changes.
    /// - Returns: A view that performs the provided action when `value` changes.
    func ub_onChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping (Value) -> Void
    ) -> some View {
        modifier(
            UBOnChangeWithValueModifier(
                value: value,
                initial: initial,
                action: action
            )
        )
    }

    // Removed: ub_noAutoCapsAndCorrection()
    // Removed: ub_toolbarTitleInline(), ub_toolbarTitleLarge()
    // Removed: ub_tabNavigationTitle(_:)

    // MARK: ub_rootNavigationChrome()
    /// Hides the navigation bar background for root-level navigation stacks on modern OS releases.
    /// Earlier platforms ignore the call so they retain their default opaque chrome.
    @ViewBuilder
    func ub_rootNavigationChrome() -> some View {
        modifier(UBRootNavigationChromeModifier())
    }

    // MARK: ub_cardTitleShadow()
    /// Tight, offset shadow for card titles (small 3D lift). Softer gray tone, not harsh black.
    /// Use on text layers: `.ub_cardTitleShadow()`
    func ub_cardTitleShadow() -> some View {
        return self.shadow(
            color: UBTypography.cardTitleShadowColor,
            radius: 0.8,
            x: 0,
            y: 1.2
        )
    }
    
    // MARK: ub_compactDatePickerStyle()
    /// Applies `.compact` date picker style where available (iPhone/iPad), no-op elsewhere.
    func ub_compactDatePickerStyle() -> some View {
        #if targetEnvironment(macCatalyst)
        return self
        #else
        return self
        #endif
    }
    
    // Removed: ub_decimalKeyboard()

    /// Applies the platform-aware OS 26 translucent background when supported,
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

    /// Applies either the custom glass background or a plain system background
    /// depending on the active theme.
    func ub_surfaceBackground(
        _ theme: AppTheme,
        configuration: AppTheme.GlassConfiguration,
        ignoringSafeArea edges: Edge.Set = []
    ) -> some View {
        modifier(
            UBSurfaceBackgroundModifier(
                theme: theme,
                configuration: configuration,
                ignoresSafeAreaEdges: edges
            )
        )
    }

    /// Applies navigation styling appropriate for the current theme. System
    /// theme favors the platform's plain backgrounds while custom themes keep
    /// the glass treatment.
    func ub_navigationBackground(
        theme: AppTheme,
        configuration: AppTheme.GlassConfiguration
    ) -> some View {
        modifier(
            UBNavigationBackgroundModifier(
                theme: theme,
                configuration: configuration
            )
        )
    }

    // (Removed) ub_navigationGlassBackground – unused wrapper.
    // (Removed) ub_chromeGlassBackground – unused wrapper.

    /// Applies theme-aware chrome styling for tab bars and other container chrome.
    func ub_chromeBackground(
        theme: AppTheme,
        configuration: AppTheme.GlassConfiguration
    ) -> some View {
        modifier(
            UBChromeBackgroundModifier(
                theme: theme,
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
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            return self.formStyle(.grouped)
        } else {
            return self
        }
    }

    // Removed: ub_sheetPadding()

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
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            return self.scrollIndicators(.hidden)
        } else {
            return self
        }
    }

    // MARK: ub_listStyleLiquidAware()
    /// Applies OS-aware list styling:
    /// - On OS 26: use `.automatic` so the system’s Liquid Glass list treatment shows through.
    /// - On earlier OSes: prefer `.insetGrouped` and hide the scroll background (iOS 16+/macOS 13+)
    ///   so our app’s surface background remains consistent.
    func ub_listStyleLiquidAware() -> some View {
        modifier(UBListStyleLiquidAwareModifier())
    }

    // MARK: ub_preOS26ListRowBackground(_:)
    /// Applies a list row background only on pre‑OS26 systems. On OS26 this is a no-op so
    /// the system’s default row background (Liquid Glass) can be used.
    func ub_preOS26ListRowBackground(_ color: Color) -> some View {
        modifier(UBPreOS26ListRowBackgroundModifier(color: color))
    }
}

// MARK: - Internal Modifiers (List Styling)
private struct UBListStyleLiquidAwareModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                content
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .ub_applyListRowSeparators()
                    .ub_applyZeroRowSpacingIfAvailable()
                    .ub_applyCompactSectionSpacingIfAvailable()
            } else {
                content
                    .listStyle(.plain)
                    .ub_applyListRowSeparators()
            }
        } else {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                content
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .ub_applyListRowSeparators()
                    .ub_applyCompactSectionSpacingIfAvailable()
            } else {
                content
                    .listStyle(.insetGrouped)
                    .ub_applyListRowSeparators()
            }
        }
    }
}

// MARK: - List Separators Helper
private extension View {
    @ViewBuilder
    func ub_applyListRowSeparators() -> some View {
        if #available(iOS 15.0, macCatalyst 15.0, *) {
            self
                .listRowSeparator(.visible)
                .listRowSeparatorTint(UBListStyleSeparators.separatorColor)
        } else {
            self
        }
    }

    @ViewBuilder
    func ub_applyCompactSectionSpacingIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            self.listSectionSpacing(.compact)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func ub_applyZeroRowSpacingIfAvailable() -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            self.listRowSpacing(0)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

private enum UBListStyleSeparators {
    static var separatorColor: Color {
        return Color(uiColor: .separator)
    }
}

private struct UBPreOS26ListRowBackgroundModifier: ViewModifier {
    let color: Color
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            content
        } else {
            content.listRowBackground(color)
        }
    }
}

// MARK: - Root Tab Navigation Title Styling
private struct UBRootNavigationChromeModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    @ViewBuilder
    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            if #available(iOS 16.0, macCatalyst 16.0, *) {
                content.toolbarBackground(.hidden, for: .navigationBar)
            } else {
                content
            }
        } else {
            content
        }
    }
}

// Removed: UBRootTabNavigationTitleModifier (no longer used)

// MARK: - Private Modifiers

private struct UBOnChangeWithoutValueModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: () -> Void
    @State private var previousValue: Value?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            content.onChange(of: value, initial: initial, action)
        } else {
            content.task(id: value) {
                let shouldTrigger: Bool
                if let previousValue {
                    shouldTrigger = previousValue != value
                } else {
                    shouldTrigger = initial
                }
                previousValue = value
                if shouldTrigger {
                    action()
                }
            }
        }
    }
}

private struct UBOnChangeWithValueModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value) -> Void
    @State private var previousValue: Value?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            content.onChange(of: value, initial: initial) { _, newValue in
                action(newValue)
            }
        } else {
            content.task(id: value) {
                let shouldTrigger: Bool
                if let previousValue {
                    shouldTrigger = previousValue != value
                } else {
                    shouldTrigger = initial
                }
                previousValue = value
                if shouldTrigger {
                    action(value)
                }
            }
        }
    }
}

// Removed: UBDecimalKeyboardModifier (no longer used)

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

private struct UBSurfaceBackgroundModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let theme: AppTheme
    let configuration: AppTheme.GlassConfiguration
    let ignoresSafeAreaEdges: Edge.Set

    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseGlassSurfaces(theme: theme, capabilities: capabilities) {
            content.ub_glassBackground(
                theme.glassBaseColor,
                configuration: configuration,
                ignoringSafeArea: ignoresSafeAreaEdges
            )
        } else {
            content.background(
                theme.background.ub_ignoreSafeArea(edges: ignoresSafeAreaEdges)
            )
        }
    }
}

private struct UBNavigationGlassModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration

    @ViewBuilder
    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            content
        } else {
            if #available(iOS 16.0, *) {
                content
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(gradientStyle, for: .navigationBar)
            } else {
                content
            }
        }
    }

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
}

// Removed: UBChromeGlassModifier (unused)

private struct UBChromeBackgroundModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let theme: AppTheme
    let configuration: AppTheme.GlassConfiguration

    func body(content: Content) -> some View {
        // On OS 26, defer to system chrome; on classic, use a flat background.
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            content
        } else {
            if #available(iOS 16.0, *) {
                content
                    .toolbarBackground(.visible, for: .tabBar)
                    .toolbarBackground(theme.background, for: .tabBar)
            } else {
                content.background(theme.background)
            }
        }
    }
}

private struct UBNavigationBackgroundModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let theme: AppTheme
    let configuration: AppTheme.GlassConfiguration

    @ViewBuilder
    func body(content: Content) -> some View {
        if UBGlassBackgroundPolicy.shouldUseGlassSurfaces(theme: theme, capabilities: capabilities) {
            content.modifier(
                UBNavigationGlassModifier(
                    baseColor: theme.glassBaseColor,
                    configuration: configuration
                )
            )
        } else {
            if #available(iOS 16.0, *) {
                content
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(theme.background, for: .navigationBar)
            } else {
                content
            }
        }
    }
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
        if capabilities.supportsOS26Translucency {
            if #available(iOS 15.0, macCatalyst 15.0, *) {
                decoratedGlass
                    .background(configuration.glass.material.shapeStyle)
            } else {
                decoratedGlass
            }
        } else {
            // Classic OS: use a flat fill that matches the theme's base color.
            Rectangle().fill(baseColor)
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

extension View {
    @ViewBuilder
    func ub_ignoreSafeArea(edges: Edge.Set) -> some View {
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            self.ignoresSafeArea(.container, edges: edges)
        } else {
            self.edgesIgnoringSafeArea(edges)
        }
    }
}

// Removed: UBColor (unused)

// MARK: - Global Helpers

/// Dismisses the on‑screen keyboard on platforms that support UIKit.
/// Call this in your save actions to neatly resign the first responder before
/// dismissing a sheet.  On macOS and other platforms this is a no‑op.
func ub_dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
