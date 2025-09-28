#if os(macOS)
import AppKit

enum SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for segmented: NSSegmentedControl) {
        if #available(macOS 26, *) {
            applyModernEqualWidth(to: segmented)
        } else {
            applyLegacyEqualWidth(to: segmented)
        }
    }

    @available(macOS 26, *)
    private static func applyModernEqualWidth(to segmented: NSSegmentedControl) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            applyManualDistributionIfPossible(segmented)
        }

        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segmented.invalidateIntrinsicContentSize()
    }

    private static func applyLegacyEqualWidth(to segmented: NSSegmentedControl) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            applyManualDistributionIfPossible(segmented)
        }

        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        guard let container = findCapsuleContainer(for: segmented) else { return }

        segmented.translatesAutoresizingMaskIntoConstraints = false

        removeLegacyConstraints(attachedTo: segmented)

        let leading = segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        leading.identifier = ConstraintIdentifier.leading
        leading.priority = .defaultHigh

        let trailing = segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        trailing.identifier = ConstraintIdentifier.trailing
        trailing.priority = .defaultHigh

        NSLayoutConstraint.activate([leading, trailing])

        segmented.invalidateIntrinsicContentSize()
    }

    private static func applyManualDistributionIfPossible(_ segmented: NSSegmentedControl) {
        let count = segmented.segmentCount
        guard count > 0 else { return }

        let totalWidth = segmented.bounds.width
        guard totalWidth > 0 else { return }

        let equalWidth = totalWidth / CGFloat(count)
        for index in 0..<count {
            segmented.setWidth(equalWidth, forSegment: index)
        }
    }

    private static func removeLegacyConstraints(attachedTo segmented: NSSegmentedControl) {
        var ancestor: NSView? = segmented
        let identifiers = Set([ConstraintIdentifier.leading, ConstraintIdentifier.trailing])

        while let view = ancestor {
            let matches = view.constraints.filter { constraint in
                guard let id = constraint.identifier, identifiers.contains(id) else { return false }
                let firstMatch = (constraint.firstItem as? NSSegmentedControl) === segmented
                let secondMatch = (constraint.secondItem as? NSSegmentedControl) === segmented
                return firstMatch || secondMatch
            }

            NSLayoutConstraint.deactivate(matches)
            ancestor = view.superview
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

    private enum ConstraintIdentifier {
        static let leading = "UBSegmentedEqualWidthLeading"
        static let trailing = "UBSegmentedEqualWidthTrailing"
    }
}
#endif
