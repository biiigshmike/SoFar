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

    // MARK: ub_noAutoCapsAndCorrection()
    /// Disables auto-capitalization and autocorrection where supported (iOS/iPadOS).
    /// On other platforms this is a no-op, allowing a single code path.
    func ub_noAutoCapsAndCorrection() -> some View {
        #if targetEnvironment(macCatalyst)
        return self
        #else
        return self
        #endif
    }

    // MARK: ub_toolbarTitleInline()
    /// Sets the navigation/toolbar title to inline across platforms.
    /// Uses the best available API per OS version and is a no-op if unavailable.
    func ub_toolbarTitleInline() -> some View {
        #if targetEnvironment(macCatalyst)
        return self
        #else
        return self
        #endif
    }

    // MARK: ub_toolbarTitleLarge()
    /// Applies a large navigation/toolbar title where supported, matching the
    /// default iOS "Settings" appearance. Falls back gracefully on platforms
    /// that do not expose the API.
    @ViewBuilder
    func ub_toolbarTitleLarge() -> some View {
        #if targetEnvironment(macCatalyst)
        self
        #else
        self
        #endif
    }

    // MARK: ub_tabNavigationTitle(_:)
    /// Convenience helper for TabView root screens to ensure the navigation
    /// title matches the tab label and uses the standard large-title display.
    /// - Parameter title: The title to show in the navigation bar.
    /// - Returns: A view with the title and large display mode applied.
    func ub_tabNavigationTitle(_ title: String) -> some View {
        modifier(UBRootTabNavigationTitleModifier(title: title))
    }

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
    
    // MARK: ub_decimalKeyboard()
    /// Uses the decimal keyboard on iOS; no-op on macOS so the same view compiles for both.
    func ub_decimalKeyboard() -> some View {
        modifier(UBDecimalKeyboardModifier())
    }

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

    /// Applies a translucent navigation bar treatment that mirrors the
    /// OS 26 surface configuration when supported by the platform.
    /// On the modern OS builds we defer entirely to the system chrome;
    /// on pre-26 releases we fall back to a subtle gradient wash that
    /// picks up the current theme's accent tint.
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

    /// Applies a platform-aware chrome background to container chrome like TabView bars
    /// tuned to the provided OS 26 configuration. UIKit-based platforms rely on
    /// their native appearance APIs, so this modifier becomes a no-op placeholder.
    func ub_chromeGlassBackground(
        baseColor: Color,
        configuration: AppTheme.GlassConfiguration
    ) -> some View {
        modifier(
            UBChromeGlassModifier(
                baseColor: baseColor,
                configuration: configuration
            )
        )
    }

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

    // MARK: ub_sheetPadding()
    /// Adds a subtle inner padding around sheet content on macOS.  On other
    /// platforms this returns `self` unchanged. 
    func ub_sheetPadding() -> some View {
        return self
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

private struct UBRootTabNavigationTitleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        return content.navigationTitle(title)
        #else
        return content.navigationTitle(title)
        #endif
    }
}

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

private struct UBDecimalKeyboardModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var platformCapabilities

    @ViewBuilder
    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        content
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

private struct UBChromeGlassModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let baseColor: Color
    let configuration: AppTheme.GlassConfiguration

    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}

private struct UBChromeBackgroundModifier: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    let theme: AppTheme
    let configuration: AppTheme.GlassConfiguration

    func body(content: Content) -> some View {
        // On OS 26, defer to system chrome; on classic, use a flat background.
        if UBGlassBackgroundPolicy.shouldUseSystemChrome(capabilities: capabilities) {
            content
        } else {
            content.background(theme.background)
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

// MARK: - UBColor (Cross-Platform Neutrals)

/// Central place for neutral system-like colors that work on iOS and macOS.
enum UBColor {
    /// Top neutral for card backgrounds.
    static var cardNeutralTop: Color {
        return Color(UIColor.secondarySystemBackground) // iOS
    }

    /// Bottom neutral for card backgrounds.
    static var cardNeutralBottom: Color {
        return Color(UIColor.tertiarySystemBackground) // iOS
    }
}

// MARK: - UBTypography (Cross-Platform text colors)

/// Typography helpers that adapt per platform.
enum UBTypography {
    /// Static title color for card text (legible dark tone on all platforms).
    static var cardTitleStatic: Color {
        return Color(UIColor.label).opacity(0.92)              // iOS: dark, dynamic
    }

    /// Softer, neutral gray for title shadows (avoids harsh pure black).
    static var cardTitleShadowColor: Color {
        return Color(.sRGB, red: 0.16, green: 0.18, blue: 0.22, opacity: 0.22)
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
