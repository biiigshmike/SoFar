import SwiftUI

/// Scaffold that standardizes the layout behaviour for root level tab pages.
///
/// Responsibilities:
/// - Captures the responsive layout context so children can make adaptive
///   decisions without repeating geometry readers.
/// - Measures header and content heights and automatically falls back to a
///   scroll view whenever the combined height exceeds the available space.
/// - Applies the app’s glass surface background and safe-area capture so
///   individual screens no longer need to repeat that boilerplate.
/// - Offers convenience helpers through ``RootTabPageProxy`` so content can
///   align to shared padding/bottom inset rules.
struct RootTabPageScaffold<Header: View, Content: View>: View {

    // MARK: Scroll Behaviour
    enum ScrollBehavior {
        case auto
        case always
        case never
    }

    // MARK: Width Constraints
    /// Optional width limits applied on macOS to keep wide layouts manageable.
    struct WidthLimits {
        var minimum: CGFloat?
        var ideal: CGFloat?
        var maximum: CGFloat?

        static var unconstrained: WidthLimits { WidthLimits() }
    }

    // MARK: Inputs
    private let scrollBehavior: ScrollBehavior
    private let spacing: CGFloat
    private let alignment: HorizontalAlignment
    private let widthLimits: WidthLimits
    /// When true, the scaffold wraps the content in its own ScrollView (keeping the
    /// header sticky). When false, the content is placed directly under the header so
    /// child lists/scroll views can manage their own scrolling (avoids nested scrolls).
    private let wrapsContentInScrollView: Bool
    private let headerBuilder: (RootTabPageProxy) -> Header
    private let contentBuilder: (RootTabPageProxy) -> Content

    // MARK: Environment
    @Environment(\.responsiveLayoutContext) private var responsiveLayoutContext
    @Environment(\.ub_safeAreaInsets) private var legacySafeAreaInsets
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var platformCapabilities

    // MARK: State
    @State private var headerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    // MARK: Init
    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        wrapsContentInScrollView: Bool = true,
        @ViewBuilder header: @escaping (RootTabPageProxy) -> Header,
        @ViewBuilder content: @escaping (RootTabPageProxy) -> Content
    ) {
        self.scrollBehavior = scrollBehavior
        self.spacing = spacing
        self.alignment = alignment
        self.widthLimits = widthLimits
        self.wrapsContentInScrollView = wrapsContentInScrollView
        self.headerBuilder = header
        self.contentBuilder = content
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        wrapsContentInScrollView: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
            wrapsContentInScrollView: wrapsContentInScrollView,
            header: { _ in header() },
            content: { _ in content() }
        )
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        wrapsContentInScrollView: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping (RootTabPageProxy) -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
            wrapsContentInScrollView: wrapsContentInScrollView,
            header: { _ in header() },
            content: content
        )
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        wrapsContentInScrollView: Bool = true,
        @ViewBuilder header: @escaping (RootTabPageProxy) -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
            wrapsContentInScrollView: wrapsContentInScrollView,
            header: header,
            content: { _ in content() }
        )
    }

    // MARK: Body
    var body: some View {
        let effectiveContext = responsiveLayoutContext
        let effectiveSafeArea = resolvedSafeAreaInsets(from: effectiveContext)
        let availableHeight = resolvedAvailableHeight(in: effectiveContext, safeArea: effectiveSafeArea)
        let combinedHeight = resolvedCombinedHeight
        let isScrollEnabled = resolvedScrollDecision(totalHeight: combinedHeight, availableHeight: availableHeight)

        let proxy = RootTabPageProxy(
            layoutContext: effectiveContext,
            safeAreaInsets: effectiveSafeArea,
            headerHeight: headerHeight,
            contentHeight: contentHeight,
            spacing: spacing,
            combinedHeight: combinedHeight,
            availableHeight: availableHeight,
            isScrollEnabled: isScrollEnabled
        )

        Group {
            if isScrollEnabled && wrapsContentInScrollView {
                // Sticky header: keep the header outside the scroll view so it
                // stays visible while the content scrolls.
                VStack(alignment: alignment, spacing: spacing) {
                    headerBuilder(proxy)
                        .background(sectionHeightReader(for: .header))

                    ScrollView(.vertical) {
                        VStack(alignment: alignment, spacing: spacing) {
                            contentBuilder(proxy)
                                .background(sectionHeightReader(for: .content))
                                #if os(iOS)
                                .background(
                                    Group {
                                        if !platformCapabilities.supportsOS26Translucency {
                                            UBScrollViewInsetAdjustmentDisabler()
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                                #endif
                        }
                        .frame(maxWidth: .infinity, alignment: stackAlignment)
                        .frame(
                            minWidth: widthLimits.minimum,
                            idealWidth: widthLimits.ideal,
                            maxWidth: widthLimits.maximum,
                            alignment: stackAlignment
                        )
                        .frame(maxWidth: .infinity, alignment: stackAlignment)
                    }
                    .ub_hideScrollIndicators()
                    // On classic OS, allow content under the tab bar and control
                    // spacing via `rootTabContentPadding`. On OS 26, respect the
                    // safe area to avoid intercepting tab bar gestures.
                    .modifier(IgnoreBottomSafeAreaIfClassic(capabilities: platformCapabilities))
                }
                .frame(maxWidth: .infinity, alignment: stackAlignment)
            } else {
                stackContent(using: proxy)
                    // Allow content to extend under the tab bar in non-scrolling
                    // layouts as well. Individual screens add any desired
                    // bottom spacing via `rootTabContentPadding`.
                    .modifier(IgnoreBottomSafeAreaIfClassic(capabilities: platformCapabilities))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: stackAlignment)
        .onPreferenceChange(RootTabSectionHeightPreferenceKey.self, perform: updateHeights)
        .ub_captureSafeAreaInsets()
        .ub_surfaceBackground(
            themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    // MARK: Stack Content
    @ViewBuilder
    private func stackContent(using proxy: RootTabPageProxy) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            headerBuilder(proxy)
                .background(sectionHeightReader(for: .header))

            contentBuilder(proxy)
                .background(sectionHeightReader(for: .content))
        }
        .frame(maxWidth: .infinity, alignment: stackAlignment)
        .frame(
            minWidth: widthLimits.minimum,
            idealWidth: widthLimits.ideal,
            maxWidth: widthLimits.maximum,
            alignment: stackAlignment
        )
        .frame(maxWidth: .infinity, alignment: stackAlignment)
    }

    private var stackAlignment: Alignment {
        Alignment(horizontal: alignment, vertical: .top)
    }

    // MARK: Height Tracking
    private func sectionHeightReader(for section: RootTabSection) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: RootTabSectionHeightPreferenceKey.self,
                    value: [section: proxy.size.height]
                )
        }
    }

    private func updateHeights(_ preferences: [RootTabSection: CGFloat]) {
        if let headerValue = preferences[.header], headerValue > 0, abs(headerValue - headerHeight) > 0.5 {
            headerHeight = headerValue
        }

        if let contentValue = preferences[.content], contentValue > 0, abs(contentValue - contentHeight) > 0.5 {
            contentHeight = contentValue
        }
    }

    private var resolvedCombinedHeight: CGFloat {
        let spacingContribution = (headerHeight > 0 && contentHeight > 0) ? spacing : 0
        return headerHeight + contentHeight + spacingContribution
    }

    private func resolvedAvailableHeight(
        in context: ResponsiveLayoutContext,
        safeArea: EdgeInsets
    ) -> CGFloat {
        guard context.containerSize.height > 0 else { return 0 }
        #if os(iOS) 
        // Allow content to extend into the bottom safe area so controls with
        // shadows (e.g., primary CTA) aren’t visually clipped. Individual
        // screens can still add bottom padding via `rootTabContentPadding`.
        let verticalInsets = safeArea.top
        #else
        let verticalInsets = safeArea.top + safeArea.bottom
        #endif
        return max(context.containerSize.height - verticalInsets, 0)
    }

    private func resolvedScrollDecision(totalHeight: CGFloat, availableHeight: CGFloat) -> Bool {
        switch scrollBehavior {
        case .always:
            return true
        case .never:
            return false
        case .auto:
            guard totalHeight > 0, availableHeight > 0 else { return false }
            let tolerance: CGFloat = 0.5
            return totalHeight - availableHeight > tolerance
        }
    }

    private func resolvedSafeAreaInsets(from context: ResponsiveLayoutContext) -> EdgeInsets {
        if legacySafeAreaInsets.hasNonZeroInsets {
            return legacySafeAreaInsets
        }

        return context.safeArea
    }
}

// MARK: - RootTabPageProxy
/// Provides downstream views with insight into the layout state calculated by
/// ``RootTabPageScaffold``. Screens can use these values to adjust padding,
/// align overlays, or make fine-grained decisions once the scaffold resolves
/// whether scrolling is required.
struct RootTabPageProxy {
    let layoutContext: ResponsiveLayoutContext
    let safeAreaInsets: EdgeInsets
    let headerHeight: CGFloat
    let contentHeight: CGFloat
    let spacing: CGFloat
    let combinedHeight: CGFloat
    let availableHeight: CGFloat
    let isScrollEnabled: Bool

    /// Controls the amount of vertical spacing inserted between tab content and the tab bar.
    enum TabBarGutter {
        case standard
        case none
        case custom(CGFloat)

        fileprivate func resolvedSpacing(defaultSpacing: CGFloat) -> CGFloat {
            switch self {
            case .standard:
                return defaultSpacing
            case .none:
                return 0
            case .custom(let value):
                return max(value, 0)
            }
        }
    }

    var availableHeightBelowHeader: CGFloat {
        let spacingContribution = (headerHeight > 0 && contentHeight > 0) ? spacing : 0
        return max(availableHeight - headerHeight - spacingContribution, 0)
    }

    /// Convenience check for compact width environments so callers can adjust layout affordances.
    var isCompactWidth: Bool {
        layoutContext.horizontalSizeClass == .compact
    }

    /// Recommended gutter spacing that removes the tab-to-content gap on compact layouts.
    var compactAwareTabBarGutter: TabBarGutter {
        isCompactWidth ? .none : .standard
    }

    var contentExceedsAvailableHeight: Bool {
        guard availableHeightBelowHeader > 0 else { return false }
        return contentHeight > availableHeightBelowHeader
    }

    var effectiveSafeAreaInsets: EdgeInsets {
        if safeAreaInsets.hasNonZeroInsets {
            return safeAreaInsets
        }

        return layoutContext.safeArea
    }

    var safeAreaBottomInset: CGFloat {
        effectiveSafeAreaInsets.bottom
    }

    var tabBarGutterSpacing: CGFloat {
        #if os(iOS)
        // Global request: remove additional gutter above the tab bar so content
        // aligns tighter across all root tabs. Safe-area padding remains
        // controlled separately via `includeSafeArea`.
        return 0
        #else
        return 0
        #endif
    }

    func tabBarGutterSpacing(_ gutter: TabBarGutter) -> CGFloat {
        gutter.resolvedSpacing(defaultSpacing: tabBarGutterSpacing)
    }

    var standardTabContentBottomPadding: CGFloat {
        safeAreaBottomInset + tabBarGutterSpacing
    }

    func tabContentBottomPadding(
        includeSafeArea: Bool = true,
        extraBottom: CGFloat = 0,
        tabBarGutter: TabBarGutter = .standard
    ) -> CGFloat {
        let safeAreaContribution = includeSafeArea ? safeAreaBottomInset : 0
        let gutterSpacing = tabBarGutterSpacing(tabBarGutter)
        return gutterSpacing + safeAreaContribution + extraBottom
    }

    func standardContentInsets(
        horizontal: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        extraTop: CGFloat = 0,
        extraBottom: CGFloat = 0,
        includeSafeArea: Bool = true,
        tabBarGutter: TabBarGutter = .standard
    ) -> EdgeInsets {
        EdgeInsets(
            top: extraTop,
            leading: horizontal,
            bottom: tabContentBottomPadding(
                includeSafeArea: includeSafeArea,
                extraBottom: extraBottom,
                tabBarGutter: tabBarGutter
            ),
            trailing: horizontal
        )
    }
}

extension RootTabPageProxy {
    /// Resolves the recommended symmetric horizontal inset for root tab content.
    ///
    /// - Parameters:
    ///   - capabilities: Platform capabilities that gate OS 26 visual treatments.
    /// - Returns: ``RootTabHeaderLayout.defaultHorizontalPadding`` when OS 26
    ///   visuals are active or the layout is wide (≥600pt). Falls back to the
    ///   leading safe-area inset on compact legacy layouts so content can align
    ///   flush with the device edges.
    func resolvedSymmetricHorizontalInset(capabilities: PlatformCapabilities) -> CGFloat {
        if capabilities.supportsOS26Translucency { return RootTabHeaderLayout.defaultHorizontalPadding }
        if layoutContext.containerSize.width >= 600 { return RootTabHeaderLayout.defaultHorizontalPadding }

        return max(effectiveSafeAreaInsets.leading, DS.Spacing.s)
    }
}

// MARK: - Preference Infrastructure
private enum RootTabSection: Hashable {
    case header
    case content
}

private struct RootTabSectionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [RootTabSection: CGFloat] { [:] }

    static func reduce(
        value: inout [RootTabSection: CGFloat],
        nextValue: () -> [RootTabSection: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Padding Helpers
private struct IgnoreBottomSafeAreaIfClassic: ViewModifier {
    let capabilities: PlatformCapabilities

    func body(content: Content) -> some View {
        if capabilities.supportsOS26Translucency {
            content // respect safe area on OS 26
        } else {
            content.ub_ignoreSafeArea(edges: .bottom)
        }
    }
}

extension View {
    /// Applies the shared horizontal and bottom padding recommended for content
    /// hosted inside a ``RootTabPageScaffold``. Accepts the proxy supplied to the
    /// header/content builders so callers don’t need to repeat safe-area logic.
    func rootTabContentPadding(
        _ proxy: RootTabPageProxy,
        horizontal: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        extraTop: CGFloat = 0,
        extraBottom: CGFloat = 0,
        includeSafeArea: Bool = true,
        tabBarGutter: RootTabPageProxy.TabBarGutter = .standard
    ) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.top, extraTop)
            .padding(
                .bottom,
                proxy.tabContentBottomPadding(
                    includeSafeArea: includeSafeArea,
                    extraBottom: extraBottom,
                    tabBarGutter: tabBarGutter
                )
            )
    }
}
