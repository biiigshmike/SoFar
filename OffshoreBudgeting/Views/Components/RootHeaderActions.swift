import SwiftUI

// MARK: - Shared Metrics
enum RootHeaderActionMetrics {
    /// Base tap target for header controls. Sized using the design system so
    /// theme updates can scale the control consistently across platforms.
    private static let legacyDimension: CGFloat = DS.Spacing.l + DS.Spacing.m

    /// Expanded Liquid Glass dimension used on macOS 26.
    private static let macExpandedDimension: CGFloat = 68

    static func dimension(for capabilities: PlatformCapabilities) -> CGFloat {
        #if os(macOS)
        if capabilities.usesExpandedMacRootHeaderMetrics {
            return Self.macExpandedDimension
        }
        #endif
        return Self.legacyDimension
    }

    /// Convenience accessor for contexts that do not have environment access.
    static var dimension: CGFloat { dimension(for: PlatformCapabilities.current) }
}

enum RootHeaderGlassMetrics {
    /// Horizontal inset around each control segment. A fraction of system
    /// spacing keeps the pill compact without hard-coded values on legacy OSs.
    private static let legacyHorizontalPadding: CGFloat = DS.Spacing.s * 0.5
    /// Vertical inset applied to the glass container.
    private static let legacyVerticalPadding: CGFloat = DS.Spacing.xs * 0.75

    /// Increased breathing room for macOS 26's Liquid Glass treatment.
    private static let macHorizontalPadding: CGFloat = DS.Spacing.m * 0.75
    private static let macVerticalPadding: CGFloat = DS.Spacing.s
    private static let macContainerSpacing: CGFloat = DS.Spacing.s

    static func horizontalPadding(for capabilities: PlatformCapabilities) -> CGFloat {
        #if os(macOS)
        if capabilities.usesExpandedMacRootHeaderMetrics {
            return Self.macHorizontalPadding
        }
        #endif
        return Self.legacyHorizontalPadding
    }

    static func verticalPadding(for capabilities: PlatformCapabilities) -> CGFloat {
        #if os(macOS)
        if capabilities.usesExpandedMacRootHeaderMetrics {
            return Self.macVerticalPadding
        }
        #endif
        return Self.legacyVerticalPadding
    }

    static func containerSpacing(for capabilities: PlatformCapabilities) -> CGFloat? {
        #if os(macOS)
        if capabilities.usesExpandedMacRootHeaderMetrics {
            return Self.macContainerSpacing
        }
        #endif
        return nil
    }

    static var horizontalPadding: CGFloat { horizontalPadding(for: PlatformCapabilities.current) }
    static var verticalPadding: CGFloat { verticalPadding(for: PlatformCapabilities.current) }
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
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(foregroundColor)
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

    private var foregroundColor: Color {
        themeManager.selectedTheme == .system ? Color.primary : Color.white
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
#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
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

private struct RootHeaderGlassNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var rootHeaderGlassEffectNamespace: Namespace.ID? {
        get { self[RootHeaderGlassNamespaceKey.self] }
        set { self[RootHeaderGlassNamespaceKey.self] = newValue }
    }
}

extension View {
    func rootHeaderGlassEffectNamespace(_ namespace: Namespace.ID?) -> some View {
        environment(\.rootHeaderGlassEffectNamespace, namespace)
    }
}

// MARK: - Header Glass Controls (iOS + macOS)
#if os(iOS) || os(macOS)

#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
@available(iOS 26, macOS 26.0, tvOS 18.0, macCatalyst 26.0, *)
private struct RootHeaderGlassCapsuleContainer<Content: View>: View {
    @Environment(\.platformCapabilities) private var capabilities
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if let spacing = RootHeaderGlassMetrics.containerSpacing(for: capabilities) {
            GlassEffectContainer(spacing: spacing) {
                content
                    .glassEffect(in: Capsule(style: .continuous))
            }
        } else {
            GlassEffectContainer {
                content
                    .glassEffect(in: Capsule(style: .continuous))
            }
        }
    }
}
#endif

private extension View {
    @ViewBuilder
    func rootHeaderGlassDecorated(
        theme: AppTheme,
        capabilities: PlatformCapabilities
    ) -> some View {
#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
        if capabilities.supportsOS26Translucency {
            if #available(iOS 26.0, macOS 26.0, tvOS 18.0, macCatalyst 26.0, *) {
                RootHeaderGlassCapsuleContainer { self }
            } else {
                // Classic fallback: reuse the legacy styling so we keep a
                // consistent visual language even when the translucent glass
                // container is unavailable at runtime.
                self.rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
            }
        } else {
            // Classic OS: return the legacy glass styling for a flat look
            // while preserving tap targets and layout metrics.
            self.rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
        }
#else
        self
#endif
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RootHeaderActionColumnsWriterKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RootHeaderActionColumnsModifier: ViewModifier {
    @Environment(\.rootHeaderActionColumnsWriter) private var writer
    let count: Int

    func body(content: Content) -> some View {
        content
            .onAppear { writer(count) }
            .ub_onChange(of: count) { newValue in writer(newValue) }
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RootHeaderActionColumnsKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

@available(iOS 16.0, macOS 13.0, *)
private extension EnvironmentValues {
    var rootHeaderActionColumnsWriter: (Int) -> Void {
        get { self[RootHeaderActionColumnsWriterKey.self] }
        set { self[RootHeaderActionColumnsWriterKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func rootHeaderActionColumns(_ count: Int) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            modifier(RootHeaderActionColumnsModifier(count: max(0, count)))
        } else {
            self
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
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

        return content
            .environment(\.rootHeaderActionColumnsWriter, writer)
            .frame(
                minWidth: RootHeaderActionMetrics.dimension(for: capabilities),
                minHeight: RootHeaderActionMetrics.dimension(for: capabilities)
            )
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding(for: capabilities))
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding(for: capabilities))
            .layoutValue(key: RootHeaderActionColumnsKey.self, value: columnCount)
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RootHeaderActionRowLayout: Layout {
    @Environment(\.platformCapabilities) private var capabilities

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding(for: capabilities)
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
        }.max() ?? (dimension + verticalPadding * 2)

        return CGSize(width: resolvedWidth, height: resolvedHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)
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
        let horizontalPadding = RootHeaderGlassMetrics.horizontalPadding(for: capabilities)
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding(for: capabilities)
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
        if #available(iOS 16.0, macOS 13.0, *) {
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
    @Environment(\.rootHeaderGlassEffectNamespace) private var glassEffectNamespace

    private let content: Content
    private let width: CGFloat?
    private let effectID: AnyHashable?

    init(width: CGFloat? = nil, effectID: AnyHashable? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.width = width
        self.effectID = effectID
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension(for: capabilities)
        let horizontalPadding = RootHeaderGlassMetrics.horizontalPadding(for: capabilities)
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding(for: capabilities)
        let resolvedWidth = width ?? dimension
        let theme = themeManager.selectedTheme

        let control = content
            .frame(width: resolvedWidth, height: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(Capsule(style: .continuous))

        control
            .rootHeaderApplyGlassEffectID(effectID, namespace: glassEffectNamespace, capabilities: capabilities)
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
    }
}

private extension View {
    @ViewBuilder
    func rootHeaderApplyGlassEffectID(
        _ effectID: AnyHashable?,
        namespace: Namespace.ID?,
        capabilities: PlatformCapabilities
    ) -> some View {
        if capabilities.usesExpandedMacRootHeaderMetrics {
            if let effectID, let namespace {
                if #available(iOS 18.0, macOS 26.0, tvOS 18.0, macCatalyst 26.0, *) {
                    self.glassEffectID(effectID, in: namespace)
                } else {
                    self
                }
            } else {
                self
            }
        } else {
            self
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
    func rootHeaderLegacyGlassDecorated(theme: AppTheme, capabilities: PlatformCapabilities) -> some View {
        let shape = Capsule(style: .continuous)
        // Classic OS style: keep it flat and subtle. No glow, no highlight,
        // no faux glass. Just a neutral fill and a light stroke.
        return self
            .background(
                shape
                    .fill(theme.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
            .overlay(
                shape
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
            )
    }
}
#endif

// MARK: - Convenience Icon Button
struct RootHeaderIconActionButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var accessibilityIdentifier: String?
    var glassEffectID: AnyHashable?
    var action: () -> Void

    init(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        glassEffectID: AnyHashable? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.glassEffectID = glassEffectID
        self.action = action
    }

    var body: some View {
        // Always use RootHeaderGlassControl to keep consistent sizing and
        // alignment with the title row. Decoration is suppressed on
        // classic OS by RootHeaderGlassControl/rootHeaderGlassDecorated.
        RootHeaderGlassControl(effectID: resolvedGlassEffectID) {
            baseButton
                .buttonStyle(RootHeaderActionButtonStyle())
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            RootHeaderControlIcon(systemImage: systemImage)
        }
        .accessibilityLabel(accessibilityLabel)
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
#if os(macOS)
        .buttonBorderShape(.circle)
        .contentShape(Circle())
#endif
    }

    private var resolvedGlassEffectID: AnyHashable? {
        glassEffectID ?? systemImage
    }
}
