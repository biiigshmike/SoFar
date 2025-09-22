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

        static let unconstrained = WidthLimits()
    }

    // MARK: Inputs
    private let scrollBehavior: ScrollBehavior
    private let spacing: CGFloat
    private let alignment: HorizontalAlignment
    private let widthLimits: WidthLimits
    private let headerBuilder: (RootTabPageProxy) -> Header
    private let contentBuilder: (RootTabPageProxy) -> Content

    // MARK: Environment
    @Environment(\.responsiveLayoutContext) private var responsiveLayoutContext
    @Environment(\.ub_safeAreaInsets) private var legacySafeAreaInsets
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: State
    @State private var headerHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    // MARK: Init
    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        @ViewBuilder header: @escaping (RootTabPageProxy) -> Header,
        @ViewBuilder content: @escaping (RootTabPageProxy) -> Content
    ) {
        self.scrollBehavior = scrollBehavior
        self.spacing = spacing
        self.alignment = alignment
        self.widthLimits = widthLimits
        self.headerBuilder = header
        self.contentBuilder = content
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
            header: { _ in header() },
            content: { _ in content() }
        )
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping (RootTabPageProxy) -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
            header: { _ in header() },
            content: content
        )
    }

    init(
        scrollBehavior: ScrollBehavior = .auto,
        spacing: CGFloat = DS.Spacing.l,
        alignment: HorizontalAlignment = .leading,
        widthLimits: WidthLimits = .unconstrained,
        @ViewBuilder header: @escaping (RootTabPageProxy) -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            scrollBehavior: scrollBehavior,
            spacing: spacing,
            alignment: alignment,
            widthLimits: widthLimits,
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
            if isScrollEnabled {
                ScrollView(.vertical) {
                    stackContent(using: proxy)
                }
                .ub_hideScrollIndicators()
            } else {
                stackContent(using: proxy)
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
        #if os(macOS)
        .frame(
            minWidth: widthLimits.minimum,
            idealWidth: widthLimits.ideal,
            maxWidth: widthLimits.maximum,
            alignment: stackAlignment
        )
        .frame(maxWidth: .infinity, alignment: stackAlignment)
        #endif
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
        let verticalInsets = safeArea.top + safeArea.bottom
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

    var availableHeightBelowHeader: CGFloat {
        let spacingContribution = (headerHeight > 0 && contentHeight > 0) ? spacing : 0
        return max(availableHeight - headerHeight - spacingContribution, 0)
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
        return effectiveSafeAreaInsets.bottom > 0 ? DS.Spacing.xs : DS.Spacing.s
        #else
        return DS.Spacing.m
        #endif
    }

    var standardTabContentBottomPadding: CGFloat {
        safeAreaBottomInset + tabBarGutterSpacing
    }

    func tabContentBottomPadding(
        includeSafeArea: Bool = true,
        extraBottom: CGFloat = 0
    ) -> CGFloat {
        let safeAreaContribution = includeSafeArea ? safeAreaBottomInset : 0
        return tabBarGutterSpacing + safeAreaContribution + extraBottom
    }

    func standardContentInsets(
        horizontal: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        extraTop: CGFloat = 0,
        extraBottom: CGFloat = 0,
        includeSafeArea: Bool = true
    ) -> EdgeInsets {
        EdgeInsets(
            top: extraTop,
            leading: horizontal,
            bottom: tabContentBottomPadding(
                includeSafeArea: includeSafeArea,
                extraBottom: extraBottom
            ),
            trailing: horizontal
        )
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
extension View {
    /// Applies the shared horizontal and bottom padding recommended for content
    /// hosted inside a ``RootTabPageScaffold``. Accepts the proxy supplied to the
    /// header/content builders so callers don’t need to repeat safe-area logic.
    func rootTabContentPadding(
        _ proxy: RootTabPageProxy,
        horizontal: CGFloat = RootTabHeaderLayout.defaultHorizontalPadding,
        extraTop: CGFloat = 0,
        extraBottom: CGFloat = 0,
        includeSafeArea: Bool = true
    ) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.top, extraTop)
            .padding(
                .bottom,
                proxy.tabContentBottomPadding(
                    includeSafeArea: includeSafeArea,
                    extraBottom: extraBottom
                )
            )
    }
}
