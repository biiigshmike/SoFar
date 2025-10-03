import SwiftUI

// MARK: - Shared Metrics
enum RootHeaderActionMetrics {
    /// Platform accessibility guidance recommends a minimum tap target of 44 pt
    /// across controls that present actionable content.
    private static let minimumTapTarget: CGFloat = 44

    /// Base tap target for header controls on platforms without the refreshed
    /// Liquid Glass treatments from the OS 26 cycle.
    private static let legacyDimension: CGFloat = max(minimumTapTarget, DS.Spacing.xxl + DS.Spacing.m)

    /// Taller control size that mirrors Apple's updated capsule buttons when
    /// Liquid Glass materials are available.
    private static let glassDimension: CGFloat = DS.Spacing.xxl + DS.Spacing.m

    /// Minimum square dimension applied to icon controls so they always
    /// meet recommended tap targets.
    static var minimumIconDimension: CGFloat { minimumTapTarget }

    /// Resolves the preferred icon dimension, clamping to the minimum tap
    /// target on legacy platforms that do not offer OS 26 glass effects.
    static func iconDimension(for capabilities: PlatformCapabilities, width: CGFloat?) -> CGFloat {
        let base = max(width ?? minimumIconDimension, minimumIconDimension)
        return capabilities.supportsOS26Translucency ? base : minimumIconDimension
    }

    /// Returns the appropriate control dimension for the supplied platform
    /// capabilities, opting into the taller OS 26 appearance when available
    /// while maintaining the legacy sizing for older systems.
    static func dimension(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? glassDimension : legacyDimension
    }

    /// Convenience for computing the minimum width of a glass control, taking
    /// the shared paddings into account so width-matching helpers stay in sync
    /// with the resolved control height.
    static func minimumGlassWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        dimension(for: capabilities) + (RootHeaderGlassMetrics.horizontalPadding * 2)
    }
}

enum RootHeaderGlassMetrics {
    /// Horizontal inset around each control segment. A fraction of system
    /// spacing keeps the pill compact without hard-coded values.
    static let horizontalPadding: CGFloat = DS.Spacing.s * 0.5
    /// Vertical inset applied to the glass container.
    static let verticalPadding: CGFloat = DS.Spacing.xs * 0.75
}

enum RootHeaderControlSizing {
    case automatic
    case icon
}

enum RootHeaderControlBackground {
    case automatic
    case clear
}

// MARK: - Icon Content
struct RootHeaderControlIcon: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var systemImage: String
    /// Optional symbol variant override keeps headers in sync with design
    /// specifications when SF Symbols offer multiple contextual variants.
    var symbolVariants: SymbolVariants? = nil

    var body: some View {
        configuredImage
            .font(.system(size: 18, weight: .regular, design: .default))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(iconForegroundStyle)
    }

    @ViewBuilder
    private var configuredImage: some View {
        if let symbolVariants {
            Image(systemName: systemImage)
                .symbolVariant(symbolVariants)
        } else {
            Image(systemName: systemImage)
        }
    }

    private var iconForegroundStyle: AnyShapeStyle {
        let theme = themeManager.selectedTheme

        switch theme {
        case .system:
            return AnyShapeStyle(.primary)
        default:
            return AnyShapeStyle(theme.resolvedTint)
        }
    }

}

// MARK: - Action Button Style
struct RootHeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Optional Accessibility Identifier
#if os(iOS) || targetEnvironment(macCatalyst) 
private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
#else
private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View { content }
}
#endif

extension View {
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(OptionalAccessibilityIdentifierModifier(identifier: identifier))
    }
}

// MARK: - Header Glass Controls
#if os(iOS)

#if os(iOS) || targetEnvironment(macCatalyst)
@available(iOS 26, macCatalyst 26.0, *)
private struct RootHeaderGlassCapsuleContainer<Content: View>: View {
    private let namespace: Namespace.ID?
    private let glassID: String?
    private let transition: GlassEffectTransition?
    private let content: Content

    init(
        namespace: Namespace.ID? = nil,
        glassID: String? = nil,
        transition: GlassEffectTransition? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.namespace = namespace
        self.glassID = glassID
        self.transition = transition
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer {
            var decorated = content
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))

            if let namespace, let glassID {
                decorated = decorated.glassEffectID(glassID, in: namespace)
            }

            if let transition {
                decorated = decorated.glassEffectTransition(transition)
            }

            decorated
        }
    }
}
#endif

private extension View {
    @ViewBuilder
    func rootHeaderGlassDecorated(
        theme: AppTheme,
        capabilities: PlatformCapabilities,
        namespace: Namespace.ID? = nil,
        glassID: String? = nil,
        transition: GlassEffectTransition? = nil
    ) -> some View {
#if os(iOS) || targetEnvironment(macCatalyst)
        if capabilities.supportsOS26Translucency {
            if #available(iOS 26.0, macCatalyst 26.0, *) {
                RootHeaderGlassCapsuleContainer(
                    namespace: namespace,
                    glassID: glassID,
                    transition: transition
                ) { self }
            } else {
                rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
            }
        } else {
            rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
        }
#else
        rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
#endif
    }
}

@available(iOS 16.0, macCatalyst 16.0, *)
private struct RootHeaderActionColumnsWriterKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

@available(iOS 16.0, macCatalyst 16.0, *)
private struct RootHeaderActionColumnsModifier: ViewModifier {
    @Environment(\.rootHeaderActionColumnsWriter) private var writer
    let count: Int

    func body(content: Content) -> some View {
        content
            .onAppear { writer(count) }
            .ub_onChange(of: count) { newValue in writer(newValue) }
    }
}

@available(iOS 16.0, macCatalyst 16.0, *)
private struct RootHeaderActionColumnsKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

@available(iOS 16.0, macCatalyst 16.0, *)
private extension EnvironmentValues {
    var rootHeaderActionColumnsWriter: (Int) -> Void {
        get { self[RootHeaderActionColumnsWriterKey.self] }
        set { self[RootHeaderActionColumnsWriterKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func rootHeaderActionColumns(_ count: Int) -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            modifier(RootHeaderActionColumnsModifier(count: max(0, count)))
        } else {
            self
        }
    }
}

@available(iOS 16.0, macCatalyst 16.0, *)
private struct RootHeaderActionSegment<Content: View>: View {
    @Environment(\.platformCapabilities) private var capabilities
    @State private var columnCount: Int
    private let content: Content

    init(defaultColumns: Int = 1, @ViewBuilder content: () -> Content) {
        let resolved = max(1, defaultColumns)
        _columnCount = State(initialValue: resolved)
        self.content = content()
    }

    var body: some View {
        let writer: (Int) -> Void = { newValue in
            let resolved = max(1, newValue)
            if columnCount != resolved {
                columnCount = resolved
            }
        }

        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)

        return content
            .environment(\.rootHeaderActionColumnsWriter, writer)
            .frame(minWidth: dimension, minHeight: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
            .layoutValue(key: RootHeaderActionColumnsKey.self, value: columnCount)
    }
}

@available(iOS 16.0, macCatalyst 16.0, *)
private struct RootHeaderActionRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let dimension = RootHeaderActionMetrics.dimension(for: PlatformCapabilities.current)
        let columnCounts = subviews.map { max(0, $0[RootHeaderActionColumnsKey.self]) }
        let actionColumnCount = columnCounts.filter { $0 > 0 }.reduce(0, +)
        let proposedSize = ProposedViewSize(width: nil, height: proposal.height)
        let fixedWidth = zip(subviews, columnCounts).reduce(CGFloat.zero) { result, element in
            let (subview, columns) = element
            guard columns == 0 else { return result }
            let size = subview.sizeThatFits(proposedSize)
            return result + size.width
        }

        let actionSizes = zip(subviews, columnCounts).compactMap { subview, columns -> (Int, CGSize)? in
            guard columns > 0 else { return nil }
            return (columns, subview.sizeThatFits(proposedSize))
        }
        let perColumnMinimum = actionSizes.reduce(CGFloat(dimension)) { result, entry in
            let (columns, size) = entry
            let widthPerColumn = size.width / CGFloat(columns)
            return max(result, widthPerColumn)
        }

        let minimumActionWidth = perColumnMinimum * CGFloat(max(actionColumnCount, 1))
        let minimumWidth = minimumActionWidth + fixedWidth
        let proposedWidth = proposal.width ?? minimumWidth
        let resolvedWidth = max(minimumWidth, proposedWidth)

        let resolvedHeight = subviews.map { subview in
            subview.sizeThatFits(proposedSize).height
        }.max() ?? (dimension + RootHeaderGlassMetrics.verticalPadding * 2)

        return CGSize(width: resolvedWidth, height: resolvedHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let dimension = RootHeaderActionMetrics.dimension(for: PlatformCapabilities.current)
        let columnCounts = subviews.map { max(0, $0[RootHeaderActionColumnsKey.self]) }
        let actionColumnCount = columnCounts.filter { $0 > 0 }.reduce(0, +)
        let proposedSize = ProposedViewSize(width: nil, height: bounds.height)
        let fixedWidths: [CGFloat] = zip(subviews, columnCounts).map { subview, columns in
            guard columns == 0 else { return 0 }
            return subview.sizeThatFits(proposedSize).width
        }

        let totalFixedWidth = fixedWidths.reduce(0, +)
        let totalColumns = max(actionColumnCount, 1)
        let availableForActions = max(bounds.width - totalFixedWidth, 0)
        let actionSizes = zip(subviews, columnCounts).compactMap { subview, columns -> (Int, CGSize)? in
            guard columns > 0 else { return nil }
            return (columns, subview.sizeThatFits(proposedSize))
        }
        let perColumnMinimum = actionSizes.reduce(CGFloat(dimension)) { result, entry in
            let (columns, size) = entry
            let widthPerColumn = size.width / CGFloat(columns)
            return max(result, widthPerColumn)
        }
        let perColumnWidth = totalColumns > 0
            ? max(availableForActions / CGFloat(totalColumns), perColumnMinimum)
            : 0

        var currentX = bounds.minX

        for index in subviews.indices {
            let subview = subviews[index]
            let columns = columnCounts[index]

            if columns == 0 {
                let width = fixedWidths[index]
                let proposal = ProposedViewSize(width: width, height: bounds.height)
                let size = subview.sizeThatFits(proposal)
                let originY = bounds.midY - size.height * 0.5
                subview.place(at: CGPoint(x: currentX, y: originY), proposal: proposal)
                currentX += width
            } else {
                let width = perColumnWidth * CGFloat(columns)
                let proposal = ProposedViewSize(width: width, height: bounds.height)
                let size = subview.sizeThatFits(proposal)
                let originY = bounds.midY - size.height * 0.5
                subview.place(at: CGPoint(x: currentX, y: originY), proposal: proposal)
                currentX += width
            }
        }
    }
}

struct RootHeaderGlassPill<Leading: View, Trailing: View, Secondary: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let leading: Leading
    private let trailing: Trailing
    private let secondary: Secondary?
    private let showsDivider: Bool
    private let hasTrailing: Bool
    private let hasSecondaryContent: Bool

    init(
        showsDivider: Bool = true,
        hasTrailing: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) where Secondary == EmptyView {
        self.init(
            leading: leading(),
            trailing: trailing(),
            secondary: nil,
            showsDivider: showsDivider,
            hasTrailing: hasTrailing
        )
    }

    init(
        showsDivider: Bool = true,
        hasTrailing: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder secondaryContent: () -> Secondary
    ) {
        self.init(
            leading: leading(),
            trailing: trailing(),
            secondary: secondaryContent(),
            showsDivider: showsDivider,
            hasTrailing: hasTrailing
        )
    }

    private init(
        leading: Leading,
        trailing: Trailing,
        secondary: Secondary?,
        showsDivider: Bool,
        hasTrailing: Bool
    ) {
        self.leading = leading
        self.trailing = trailing
        self.secondary = secondary
        self.showsDivider = showsDivider
        self.hasTrailing = hasTrailing
        self.hasSecondaryContent = secondary != nil
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)
        let horizontalPadding = RootHeaderGlassMetrics.horizontalPadding
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding
        let theme = themeManager.selectedTheme

        let content = VStack(spacing: 0) {
            buildPrimaryRow(
                dimension: dimension,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                theme: theme
            )

            if hasSecondaryContent, let secondary {
                Divider()
                    .overlay(RootHeaderLegacyGlass.dividerColor(for: theme))
                    .padding(.horizontal, horizontalPadding)

                secondary
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
            }
        }
        .contentShape(Capsule(style: .continuous))

        return content
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
    }

    @ViewBuilder
    private func buildPrimaryRow(
        dimension: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        theme: AppTheme
    ) -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            RootHeaderActionRowLayout {
                RootHeaderActionSegment {
                    leading
                }

                if showsDivider {
                    makeDividerView(theme: theme, dimension: dimension, verticalPadding: verticalPadding)
                        .layoutValue(key: RootHeaderActionColumnsKey.self, value: 0)
                }

                if hasTrailing {
                    RootHeaderActionSegment {
                        trailing
                    }
                }
            }
        } else {
            legacyPrimaryRow(
                dimension: dimension,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                theme: theme
            )
        }
    }

    @ViewBuilder
    private func legacyPrimaryRow(
        dimension: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        theme: AppTheme
    ) -> some View {
        HStack(spacing: 0) {
            legacyActionSegment(
                leading,
                dimension: dimension,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )

            if showsDivider {
                makeDividerView(theme: theme, dimension: dimension, verticalPadding: verticalPadding)
            }

            if hasTrailing {
                legacyActionSegment(
                    trailing,
                    dimension: dimension,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legacyActionSegment<Content: View>(
        _ content: Content,
        dimension: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        content
            .frame(minWidth: dimension, maxWidth: .infinity, minHeight: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }

    private func makeDividerView(
        theme: AppTheme,
        dimension: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        Rectangle()
            .fill(RootHeaderLegacyGlass.dividerColor(for: theme))
            .frame(width: 1, height: dimension)
            .padding(.vertical, verticalPadding)
    }
}

struct RootHeaderGlassControl<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let width: CGFloat?
    private let sizing: RootHeaderControlSizing
    private let background: RootHeaderControlBackground
    private let glassNamespace: Namespace.ID?
    private let glassID: String?
    private let glassTransition: GlassEffectTransition?

    init(
        width: CGFloat? = nil,
        sizing: RootHeaderControlSizing = .automatic,
        background: RootHeaderControlBackground = .automatic,
        glassNamespace: Namespace.ID? = nil,
        glassID: String? = nil,
        glassTransition: GlassEffectTransition? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.width = width
        self.sizing = sizing
        self.background = background
        self.glassNamespace = glassNamespace
        self.glassID = glassID
        self.glassTransition = glassTransition
    }

    @ViewBuilder
    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)
        let theme = themeManager.selectedTheme

        if sizing == .icon {
            let d = RootHeaderActionMetrics.minimumIconDimension
            let iconSide = RootHeaderActionMetrics.iconDimension(for: capabilities, width: width)
            let fallbackSide = RootHeaderActionMetrics.minimumIconDimension

            if background == .clear {
                let side = capabilities.supportsOS26Translucency ? max(iconSide, d) : fallbackSide

                content
                    .frame(width: side, height: side)
                    .background(Color.clear)
                    .contentShape(Circle())
            } else {

#if os(iOS) || targetEnvironment(macCatalyst)
                if capabilities.supportsOS26Translucency {
                    if #available(iOS 26.0, macCatalyst 26.0, *) {
                        RootHeaderGlassCapsuleContainer(
                            namespace: glassNamespace,
                            glassID: glassID,
                            transition: glassTransition
                        ) {
                            content
                                .frame(width: max(iconSide, d), height: max(iconSide, d))
                        }
                        .contentShape(Circle())
                    } else {
                        content
                            .frame(width: fallbackSide, height: fallbackSide)
                            .contentShape(Circle())
                    }
                } else {
                    content
                        .frame(width: fallbackSide, height: fallbackSide)
                        .contentShape(Circle())
                }
#else
                content
                    .frame(width: fallbackSide, height: fallbackSide)
                    .contentShape(Circle())
#endif
            }
        } else {
            content
                .modifier(RootHeaderGlassControlFrameModifier(width: width, dimension: dimension))
                .contentShape(Rectangle())
                .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
                .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
                .contentShape(Capsule(style: .continuous))
                .rootHeaderGlassDecorated(
                    theme: theme,
                    capabilities: capabilities,
                    namespace: glassNamespace,
                    glassID: glassID,
                    transition: glassTransition
                )
        }
    }
}

private struct RootHeaderGlassControlFrameModifier: ViewModifier {
    let width: CGFloat?
    let dimension: CGFloat

    func body(content: Content) -> some View {
        if let width {
            content
                .frame(width: width, height: dimension)
        } else {
            content
                .frame(
                    minWidth: dimension,
                    idealWidth: dimension,
                    maxWidth: .infinity,
                    minHeight: dimension,
                    maxHeight: dimension
                )
        }
    }
}

enum RootHeaderLegacyGlass {
    static func fillColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.30) : theme.resolvedTint.opacity(0.32)
    }

    static func shadowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.black.opacity(0.28) : theme.resolvedTint.opacity(0.42)
    }

    static func borderColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.50) : theme.resolvedTint.opacity(0.58)
    }

    static func dividerColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.50) : theme.resolvedTint.opacity(0.55)
    }

    static func glowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white : theme.resolvedTint
    }

    static func glowOpacity(for theme: AppTheme) -> Double {
        theme == .system ? 0.32 : 0.42
    }

    static func borderLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 1.15 : 1.0
    }

    static func highlightLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 0.9 : 0.8
    }

    static func highlightOpacity(for capabilities: PlatformCapabilities) -> Double {
        capabilities.supportsOS26Translucency ? 0.24 : 0.18
    }

    static func glowLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 12 : 9
    }

    static func glowBlurRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowYOffset(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 10 : 9
    }
}

extension View {
    @ViewBuilder
    func rootHeaderLegacyGlassDecorated(theme: AppTheme, capabilities: PlatformCapabilities) -> some View {
        let shape = Capsule(style: .continuous)
        let borderStroke = shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.8)

        if capabilities.supportsOS26Translucency {
            // Preserve the existing legacy fallback for modern devices so the
            // capsule continues to match the glass baseline.
            self
                .background(
                    shape
                        .fill(theme.secondaryBackground)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .overlay(borderStroke)
        } else {
            // Older platforms should mirror the lighter OS 26 styling without
            // the gray-tinted drop shadow.
            self
                .background(
                    shape
                        .fill(theme.background)
                )
                .overlay(borderStroke)
        }
    }
}
#endif

// MARK: - Convenience Icon Button
struct RootHeaderIconActionButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var accessibilityIdentifier: String?
    var action: () -> Void
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager

    init(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)

        if capabilities.supportsOS26Translucency, #available(iOS 26.0, macCatalyst 26.0, *) {
            Button(action: action) {
                RootHeaderControlIcon(systemImage: systemImage)
                    .frame(width: dimension, height: dimension)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(themeManager.selectedTheme.resolvedTint)
            .accessibilityLabel(accessibilityLabel)
            .optionalAccessibilityIdentifier(accessibilityIdentifier)
        } else {
            returnLegacy
        }
    }

    @ViewBuilder
    private var returnLegacy: some View {
        RootHeaderGlassControl(sizing: .icon) {
            Button(action: action) {
                RootHeaderControlIcon(systemImage: systemImage)
            }
            .buttonStyle(RootHeaderActionButtonStyle())
            .accessibilityLabel(accessibilityLabel)
            .optionalAccessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
