import SwiftUI

struct SegmentedControlGlassContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.responsiveLayoutContext) private var layoutContext
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let contentAlignment: Alignment

    init(
        horizontalPadding: CGFloat = DS.Spacing.l,
        verticalPadding: CGFloat = DS.Spacing.m,
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.contentAlignment = alignment
    }

    var body: some View {
        let _ = themeManager
        let _ = layoutContext
        let capsule = Capsule(style: .continuous)
        let decorated = content
            .frame(maxWidth: .infinity, alignment: contentAlignment)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .contentShape(capsule)

        if #available(iOS 26.0, macOS 26.0, tvOS 18.0, macCatalyst 26.0, *), capabilities.supportsOS26Translucency {
            GlassEffectContainer {
                decorated
                    .glassEffect(.regular.interactive(), in: capsule)
            }
        } else {
            decorated
        }
    }
}

extension View {
    func segmentedControlFill() -> some View {
        frame(maxWidth: .infinity)
    }

    func segmentedControlEqualWidth() -> some View {
        modifier(SegmentedControlEqualWidthModifier())
    }
}

private struct SegmentedControlEqualWidthModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
#if os(iOS)
        content.background(
            SegmentedControlEqualWidthApplier(palette: themeManager.selectedTheme.glassPalette)
        )
#elif os(macOS)
        content.background(
            SegmentedControlEqualWidthApplier(palette: themeManager.selectedTheme.glassPalette)
        )
#else
        content
#endif
    }
}

#if os(iOS)
private struct SegmentedControlEqualWidthApplier: UIViewRepresentable {
    let palette: AppTheme.GlassConfiguration.Palette

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: uiView)
        }
    }

    private func applyEqualWidthIfNeeded(from view: UIView) {
        guard let segmented = findSegmentedControl(from: view) else { return }
        segmented.apportionsSegmentWidthsByContent = false
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        applyMacCatalystLiquidGlassIfNeeded(to: segmented)
        segmented.invalidateIntrinsicContentSize()
    }

    private func findSegmentedControl(from view: UIView) -> UISegmentedControl? {
        var current: UIView? = view
        while let candidate = current {
            if let segmented = candidate as? UISegmentedControl {
                return segmented
            }
            current = candidate.superview
        }
        return nil
    }

    private func applyMacCatalystLiquidGlassIfNeeded(to segmented: UISegmentedControl) {
#if targetEnvironment(macCatalyst)
        if #available(macCatalyst 26.0, *) {
            segmented.selectedSegmentTintColor = UIColor(palette.accent)
            segmented.tintColor = UIColor(palette.accent)
            segmented.backgroundColor = UIColor(palette.shadow).withAlphaComponent(0.12)
        }
#endif
    }
}
#elif os(macOS)
private struct SegmentedControlEqualWidthApplier: NSViewRepresentable {
    let palette: AppTheme.GlassConfiguration.Palette

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0.0
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: view, context: context)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: nsView, context: context)
        }
    }

    private func applyEqualWidthIfNeeded(from view: NSView, context: Context) {
        guard let segmented = findSegmentedControl(from: view) else { return }
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            let count = segmented.segmentCount
            guard count > 0 else { return }
            let totalWidth = segmented.bounds.width
            guard totalWidth > 0 else { return }
            let equalWidth = totalWidth / CGFloat(count)
            for index in 0..<count {
                segmented.setWidth(equalWidth, forSegment: index)
            }
        }
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyCapsulePinning(to: segmented, context: context)
        applyLiquidGlassAppearanceIfNeeded(to: segmented)
        segmented.invalidateIntrinsicContentSize()
    }

    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        guard let root = view.superview else { return nil }
        return searchSegmented(in: root)
    }

    private func searchSegmented(in node: NSView) -> NSSegmentedControl? {
        for sub in node.subviews {
            if let seg = sub as? NSSegmentedControl {
                return seg
            }
            if let found = searchSegmented(in: sub) {
                return found
            }
        }
        return nil
    }

    private func applyCapsulePinning(to segmented: NSSegmentedControl, context: Context) {
        let cache = context.coordinator.constraintCache
        guard let container = findCapsuleContainer(for: segmented) ?? segmented.superview else {
            cache.deactivateAll()
            return
        }

        segmented.translatesAutoresizingMaskIntoConstraints = false
        cache.activate(
            key: ConstraintCache.Key.leading,
            segmented: segmented,
            container: container
        ) {
            segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        }

        cache.activate(
            key: ConstraintCache.Key.trailing,
            segmented: segmented,
            container: container
        ) {
            segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        }

        cache.removeAll(except: [ConstraintCache.Key.leading, ConstraintCache.Key.trailing])
    }

    private func findCapsuleContainer(for segmented: NSSegmentedControl) -> NSView? {
        var candidate = segmented.superview
        while let view = candidate {
            if isCapsuleContainer(view) {
                return view
            }
            candidate = view.superview
        }
        return nil
    }

    private func isCapsuleContainer(_ view: NSView) -> Bool {
        if view is NSSegmentedControl { return false }
        if view is NSVisualEffectView { return true }
        if let layer = view.layer {
            if layer.cornerRadius > 0 { return true }
            if layer.mask != nil { return true }
        }
        return false
    }

    private func applyLiquidGlassAppearanceIfNeeded(to segmented: NSSegmentedControl) {
        guard #available(macOS 26.0, *) else { return }
        segmented.segmentStyle = .capsule
        segmented.bezelStyle = .rounded
        segmented.contentTintColor = NSColor(palette.accent)

        if segmented.responds(to: Selector(("setContentBorderColor:forSegment:"))) {
            let rimColor = NSColor(palette.rim).withAlphaComponent(0.30)
            for index in 0..<segmented.segmentCount {
                segmented.setContentBorderColor(rimColor, forSegment: index)
            }
        }
    }

    final class Coordinator {
        let constraintCache = ConstraintCache()
    }

    final class ConstraintCache {
        enum Key: Hashable {
            case leading
            case trailing
        }

        private var constraints: [Key: NSLayoutConstraint] = [:]

        func activate(
            key: Key,
            segmented: NSSegmentedControl,
            container: NSView,
            builder: () -> NSLayoutConstraint
        ) {
            if let existing = constraints[key],
               existing.firstItem === segmented,
               existing.secondItem === container {
                if !existing.isActive {
                    existing.isActive = true
                }
                return
            }

            if let existing = constraints[key] {
                existing.isActive = false
            }

            let constraint = builder()
            constraint.isActive = true
            constraints[key] = constraint
        }

        func removeAll(except keys: [Key]) {
            let keep = Set(keys)
            let removable = constraints.filter { !keep.contains($0.key) }
            for (key, constraint) in removable {
                constraint.isActive = false
                constraints.removeValue(forKey: key)
            }
        }

        func deactivateAll() {
            for (_, constraint) in constraints {
                constraint.isActive = false
            }
            constraints.removeAll()
        }
    }
}
#endif
