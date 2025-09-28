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
    func body(content: Content) -> some View {
#if os(iOS)
        content.background(SegmentedControlEqualWidthApplier())
#elif os(macOS)
        content.background(SegmentedControlEqualWidthApplier())
#else
        content
#endif
    }
}

#if os(iOS)
private struct SegmentedControlEqualWidthApplier: UIViewRepresentable {
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
}
#elseif os(macOS)
private struct SegmentedControlEqualWidthApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0.0
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyEqualWidthIfNeeded(from: nsView)
        }
    }

    private func applyEqualWidthIfNeeded(from view: NSView) {
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
        if let superview = segmented.superview {
            segmented.translatesAutoresizingMaskIntoConstraints = false
            if segmented.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive == false {
                segmented.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
            }
            if segmented.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive == false {
                segmented.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
            }
        }
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
}
#endif
