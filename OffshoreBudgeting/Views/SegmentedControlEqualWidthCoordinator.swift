#if os(macOS)
import AppKit
import ObjectiveC
import SwiftUI

enum SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for segmented: NSSegmentedControl) {
        applyDistributionIfNeeded(to: segmented)
        if #available(macOS 26.0, *), PlatformCapabilities.current.supportsOS26Translucency {
            return
        }
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyContainerConstraints(to: segmented)
        segmented.invalidateIntrinsicContentSize()
    }

    private static func applyDistributionIfNeeded(to segmented: NSSegmentedControl) {
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
    }

    private static func applyContainerConstraints(to segmented: NSSegmentedControl) {
        let cache = constraintCache(for: segmented)
        let container = findCapsuleContainer(for: segmented)

        if cache.container !== container {
            cache.deactivateAll()
            cache.container = container
        }

        guard let container else { return }

        segmented.translatesAutoresizingMaskIntoConstraints = false

        if let leading = cache.leading {
            leading.isActive = true
        } else {
            let leading = segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
            leading.priority = .defaultHigh
            leading.isActive = true
            cache.leading = leading
        }

        if let trailing = cache.trailing {
            trailing.isActive = true
        } else {
            let trailing = segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            trailing.priority = .defaultHigh
            trailing.isActive = true
            cache.trailing = trailing
        }

        if container !== segmented.superview {
            if let width = cache.width {
                width.isActive = true
            } else {
                let width = segmented.widthAnchor.constraint(equalTo: container.widthAnchor)
                width.priority = .defaultHigh
                width.isActive = true
                cache.width = width
            }
        } else if let width = cache.width {
            width.isActive = false
            cache.width = nil
        }
    }

    private static func findCapsuleContainer(for segmented: NSSegmentedControl) -> NSView? {
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

    private static func isHostingView(_ view: NSView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        return className.contains("NSHostingView") || className.contains("ViewHost") || className.contains("HostingView")
    }

    private static func constraintCache(for segmented: NSSegmentedControl) -> ConstraintCache {
        if let existing = objc_getAssociatedObject(segmented, &AssociatedKeys.constraintCacheKey) as? ConstraintCache {
            return existing
        }
        let storage = ConstraintCache()
        objc_setAssociatedObject(segmented, &AssociatedKeys.constraintCacheKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return storage
    }

    private final class ConstraintCache {
        weak var container: NSView?
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
