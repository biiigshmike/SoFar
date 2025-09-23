import SwiftUI

// MARK: - Shared Metrics
enum RootHeaderActionMetrics {
    /// Base tap target for header controls. Sized using the design system so
    /// theme updates can scale the control consistently across platforms.
    static let dimension: CGFloat = DS.Spacing.l + DS.Spacing.m
}

enum RootHeaderGlassMetrics {
    /// Horizontal inset around each control segment. A fraction of system
    /// spacing keeps the pill compact without hard-coded values.
    static let horizontalPadding: CGFloat = DS.Spacing.s * 0.5
    /// Vertical inset applied to the glass container.
    static let verticalPadding: CGFloat = DS.Spacing.xs * 0.75
}

// MARK: - Icon Content
struct RootHeaderControlIcon: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(foregroundColor)
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

// MARK: - Header Glass Controls (iOS + macOS)
#if os(iOS) || os(macOS)

#if os(iOS) || os(macOS) || os(tvOS) || targetEnvironment(macCatalyst)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, macCatalyst 18.0, *)
private struct RootHeaderGlassCapsuleContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer {
            content
                .glassEffect(in: Capsule(style: .continuous))
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
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, macCatalyst 18.0, *) {
                RootHeaderGlassCapsuleContainer { self }
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

private struct RootHeaderActionColumnsWriterKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

private struct RootHeaderActionColumnsModifier: ViewModifier {
    @Environment(\.rootHeaderActionColumnsWriter) private var writer
    let count: Int

    func body(content: Content) -> some View {
        content
            .onAppear { writer(count) }
            .onChange(of: count) { _, newValue in writer(newValue) }
    }
}

private struct RootHeaderActionColumnsKey: LayoutValueKey {
    static let defaultValue: Int = 1
}

private extension EnvironmentValues {
    var rootHeaderActionColumnsWriter: (Int) -> Void {
        get { self[RootHeaderActionColumnsWriterKey.self] }
        set { self[RootHeaderActionColumnsWriterKey.self] = newValue }
    }
}

extension View {
    func rootHeaderActionColumns(_ count: Int) -> some View {
        modifier(RootHeaderActionColumnsModifier(count: max(0, count)))
    }
}

private struct RootHeaderActionSegment<Content: View>: View {
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
            .frame(minWidth: RootHeaderActionMetrics.dimension, minHeight: RootHeaderActionMetrics.dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
            .layoutValue(key: RootHeaderActionColumnsKey.self, value: columnCount)
    }
}

private struct RootHeaderActionRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
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
        let perColumnMinimum = actionSizes.reduce(CGFloat(RootHeaderActionMetrics.dimension)) { result, entry in
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
        }.max() ?? (RootHeaderActionMetrics.dimension + RootHeaderGlassMetrics.verticalPadding * 2)

        return CGSize(width: resolvedWidth, height: resolvedHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
        let perColumnMinimum = actionSizes.reduce(CGFloat(RootHeaderActionMetrics.dimension)) { result, entry in
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
        let dimension = RootHeaderActionMetrics.dimension
        let horizontalPadding = RootHeaderGlassMetrics.horizontalPadding
        let verticalPadding = RootHeaderGlassMetrics.verticalPadding
        let theme = themeManager.selectedTheme

        let primaryRow = RootHeaderActionRowLayout {
            RootHeaderActionSegment {
                leading
            }

            if showsDivider {
                Rectangle()
                    .fill(RootHeaderLegacyGlass.dividerColor(for: theme))
                    .frame(width: 1, height: dimension)
                    .padding(.vertical, verticalPadding)
                    .layoutValue(key: RootHeaderActionColumnsKey.self, value: 0)
            }

            if hasTrailing {
                RootHeaderActionSegment {
                    trailing
                }
            }
        }

        let content = VStack(spacing: 0) {
            primaryRow

            if hasSecondaryContent, let secondary {
                Divider()
                    .overlay(RootHeaderLegacyGlass.dividerColor(for: theme))
                    .padding(.horizontal, horizontalPadding)

                secondary
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
            }
        }
        .contentShape(Capsule(style: .continuous))

        content
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
    }
}

struct RootHeaderGlassControl<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let width: CGFloat?

    init(width: CGFloat? = RootHeaderActionMetrics.dimension, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.width = width
    }

    var body: some View {
        let dimension = RootHeaderActionMetrics.dimension
        let theme = themeManager.selectedTheme

        let control = content
            .frame(width: width, height: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
            .contentShape(Capsule(style: .continuous))

        control
            .rootHeaderGlassDecorated(theme: theme, capabilities: capabilities)
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
        return self
            .background(
                shape
                    .fill(RootHeaderLegacyGlass.fillColor(for: theme))
                    .shadow(
                        color: RootHeaderLegacyGlass.shadowColor(for: theme),
                        radius: RootHeaderLegacyGlass.shadowRadius(for: capabilities),
                        x: 0,
                        y: RootHeaderLegacyGlass.shadowYOffset(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.borderColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.borderLineWidth(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        Color.white.opacity(RootHeaderLegacyGlass.highlightOpacity(for: capabilities)),
                        lineWidth: RootHeaderLegacyGlass.highlightLineWidth(for: capabilities)
                    )
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.glowColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.glowLineWidth(for: capabilities)
                    )
                    .blur(radius: RootHeaderLegacyGlass.glowBlurRadius(for: capabilities))
                    .opacity(RootHeaderLegacyGlass.glowOpacity(for: theme))
                    .blendMode(.screen)
            )
            .compositingGroup()
    }
}
#endif

// MARK: - Convenience Icon Button
struct RootHeaderIconActionButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var accessibilityIdentifier: String?
    var action: () -> Void

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
        RootHeaderGlassControl {
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
}
