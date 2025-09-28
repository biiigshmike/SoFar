#if os(macOS)
import AppKit
import ObjectiveC

enum SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for segmented: NSSegmentedControl) {
        applyDistributionIfNeeded(to: segmented)
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
        cache.deactivateAll()

        guard let container = findCapsuleContainer(for: segmented) else { return }

        segmented.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint] = []

        let leading = segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        leading.priority = .defaultHigh
        constraints.append(leading)

        let trailing = segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        trailing.priority = .defaultHigh
        constraints.append(trailing)

        if container !== segmented.superview {
            let width = segmented.widthAnchor.constraint(equalTo: container.widthAnchor)
            width.priority = .defaultHigh
            constraints.append(width)
        }

        cache.store(constraints)
    }

    private static func findCapsuleContainer(for segmented: NSSegmentedControl) -> NSView? {
        var current: NSView? = segmented.superview
        var ancestorsBeforeHosting: [NSView] = []
        var ancestorsAfterHosting: [NSView] = []
        var encounteredHostingAncestor = false

        while let candidate = current {
            if isHostingView(candidate) {
                encounteredHostingAncestor = true
            } else if encounteredHostingAncestor {
                ancestorsAfterHosting.append(candidate)
            } else {
                ancestorsBeforeHosting.append(candidate)
            }
            current = candidate.superview
        }

        for candidate in ancestorsAfterHosting {
            if isCapsuleContainer(candidate) {
                return candidate
            }
        }

        if let fallback = ancestorsAfterHosting.first {
            return fallback
        }

        for candidate in ancestorsBeforeHosting.reversed() {
            if isCapsuleContainer(candidate) {
                return candidate
            }
        }

        return ancestorsBeforeHosting.last ?? segmented.superview
    }

    private static func isHostingView(_ view: NSView) -> Bool {
        let className = NSStringFromClass(type(of: view))
        return className.contains("NSHostingView") || className.contains("ViewHost") || className.contains("HostingView")
    }

    private static func isCapsuleContainer(_ view: NSView) -> Bool {
        if view is NSVisualEffectView {
            return true
        }

        let className = NSStringFromClass(type(of: view))
        if className.contains("GlassEffectContainer") || className.contains("GlassEffectView") {
            return true
        }

        if className.contains("NSVisualEffectView") {
            return true
        }

        if className.contains("Capsule") {
            return true
        }

        return false
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
        private var constraints: [NSLayoutConstraint] = []

        func store(_ constraints: [NSLayoutConstraint]) {
            self.constraints = constraints
            NSLayoutConstraint.activate(constraints)
        }

        func deactivateAll() {
            NSLayoutConstraint.deactivate(constraints)
            constraints.removeAll()
        }
    }

    private enum AssociatedKeys {
        static var constraintCacheKey: UInt8 = 0
    }
}
#endif
