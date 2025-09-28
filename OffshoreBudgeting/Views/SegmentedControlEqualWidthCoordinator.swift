#if os(macOS)
import AppKit

enum SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for segmented: NSSegmentedControl) {
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        guard let container = resolveContainer(for: segmented) else {
            if #available(macOS 13.0, *) {
                segmented.segmentDistribution = .fillEqually
            }
            segmented.invalidateIntrinsicContentSize()
            return
        }

        container.layoutSubtreeIfNeeded()
        applyDistribution(for: segmented, in: container)
        applyLayoutConstraints(for: segmented, in: container)
        segmented.invalidateIntrinsicContentSize()
    }

    private static func applyDistribution(for segmented: NSSegmentedControl, in container: NSView) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            let count = segmented.segmentCount
            guard count > 0 else { return }
            let totalWidth = container.bounds.width
            guard totalWidth > 0 else { return }
            let equalWidth = totalWidth / CGFloat(count)
            for index in 0..<count {
                segmented.setWidth(equalWidth, forSegment: index)
            }
        }
    }

    private static func applyLayoutConstraints(for segmented: NSSegmentedControl, in container: NSView) {
        segmented.translatesAutoresizingMaskIntoConstraints = false

        deactivateEqualWidthConstraints(for: segmented, in: container)

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

        NSLayoutConstraint.activate(constraints)
    }

    private static func deactivateEqualWidthConstraints(for segmented: NSSegmentedControl, in container: NSView) {
        let candidates = container.constraints + segmented.constraints

        let toDeactivate = candidates.filter { constraint in
            guard let firstView = constraint.firstItem as? NSView else { return false }
            let secondView = constraint.secondItem as? NSView

            switch (firstView, constraint.firstAttribute, secondView, constraint.secondAttribute) {
            case (segmented, .leading, container, .leading),
                 (segmented, .trailing, container, .trailing),
                 (segmented, .width, container, .width),
                 (container, .leading, segmented, .leading),
                 (container, .trailing, segmented, .trailing),
                 (container, .width, segmented, .width):
                return true
            default:
                return false
            }
        }

        NSLayoutConstraint.deactivate(toDeactivate)
    }

    private static func resolveContainer(for segmented: NSSegmentedControl) -> NSView? {
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
}

final class SegmentedControlLayoutObserverView: NSView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onLayout?()
    }
}
#endif
