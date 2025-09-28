//
//  GlassCapsuleContainer.swift
//  SoFar
//
//  Shared glass-styled container and segmented control helpers used across
//  BudgetDetailsView and HomeView.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
import ObjectiveC
#endif

// MARK: - GlassCapsuleContainer
internal struct GlassCapsuleContainer<Content: View>: View {
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let contentAlignment: Alignment

    internal init(
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

// MARK: - Segmented control helpers
internal extension View {
    func segmentedFill() -> some View {
        frame(maxWidth: .infinity)
    }

    func equalWidthSegments() -> some View {
        modifier(EqualWidthSegmentsModifier())
    }
}

internal struct EqualWidthSegmentsModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.background(EqualWidthSegmentApplier())
#elseif os(macOS)
        content.background(EqualWidthSegmentApplier())
#else
        content
#endif
    }
}

#if os(iOS)
internal struct EqualWidthSegmentApplier: UIViewRepresentable {
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
internal struct EqualWidthSegmentApplier: NSViewRepresentable {
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

        let cache = constraintCache(for: segmented)
        cache.deactivateAll()

        if let container = findCapsuleContainer(for: segmented) {
            segmented.translatesAutoresizingMaskIntoConstraints = false
            cache.container = container

            cache.leading = segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
            cache.trailing = segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)

            cache.leading?.isActive = true
            cache.trailing?.isActive = true
        } else {
            segmented.translatesAutoresizingMaskIntoConstraints = false
            cache.width = segmented.widthAnchor.constraint(equalToConstant: segmented.bounds.width)
            cache.width?.isActive = true
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

    private func findCapsuleContainer(for segmented: NSSegmentedControl) -> NSView? {
        var current: NSView? = segmented.superview
        var encounteredHostingAncestor = false

        while let candidate = current {
            if isHostingView(candidate) {
                encounteredHostingAncestor = true
            } else if encounteredHostingAncestor {
                return candidate
            }
            current = candidate.superview
        }

        return segmented.superview
    }

    private func isHostingView(_ view: NSView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        return className.contains("NSHostingView") || className.contains("ViewHost") || className.contains("HostingView")
    }

    private func constraintCache(for segmented: NSSegmentedControl) -> ConstraintCache {
        if let existing = objc_getAssociatedObject(segmented, &AssociatedKeys.constraintCacheKey) as? ConstraintCache {
            return existing
        }
        let storage = ConstraintCache()
        objc_setAssociatedObject(segmented, &AssociatedKeys.constraintCacheKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return storage
    }

    private final class ConstraintCache {
        var container: NSView?
        var leading: NSLayoutConstraint?
        var trailing: NSLayoutConstraint?
        var width: NSLayoutConstraint?

        func deactivateAll() {
            [leading, trailing, width].forEach { constraint in
                constraint?.isActive = false
            }
            leading = nil
            trailing = nil
            width = nil
        }
    }

    private enum AssociatedKeys {
        static var constraintCacheKey: UInt8 = 0
    }
}
#endif
