#if os(macOS)
import AppKit

enum SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for segmented: NSSegmentedControl) {
        segmented.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmented.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if #available(macOS 26, *) {
            segmented.segmentStyle = .capsule
            segmented.controlSize = .large
        }

        enforceLegacyEqualWidth(for: segmented)
    }

    private static func enforceLegacyEqualWidth(for segmented: NSSegmentedControl) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        } else {
            applyManualEqualWidthDistribution(to: segmented)
        }

        segmented.translatesAutoresizingMaskIntoConstraints = false

        guard let container = findCapsuleContainer(for: segmented) else {
            segmented.invalidateIntrinsicContentSize()
            return
        }

        deactivateManagedConstraints(on: segmented, container: container)

        var constraints: [NSLayoutConstraint] = []

        let leading = segmented.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        leading.priority = .defaultHigh
        leading.identifier = ConstraintIdentifier.leading.rawValue
        constraints.append(leading)

        let trailing = segmented.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        trailing.priority = .defaultHigh
        trailing.identifier = ConstraintIdentifier.trailing.rawValue
        constraints.append(trailing)

        if container !== segmented.superview {
            let width = segmented.widthAnchor.constraint(equalTo: container.widthAnchor)
            width.priority = .defaultHigh
            width.identifier = ConstraintIdentifier.width.rawValue
            constraints.append(width)
        }

        NSLayoutConstraint.activate(constraints)
        segmented.invalidateIntrinsicContentSize()
    }

    private static func applyManualEqualWidthDistribution(to segmented: NSSegmentedControl) {
        let count = segmented.segmentCount
        guard count > 0 else { return }
        let totalWidth = segmented.bounds.width
        guard totalWidth > 0 else { return }
        let equalWidth = totalWidth / CGFloat(count)
        for index in 0..<count {
            segmented.setWidth(equalWidth, forSegment: index)
        }
    }

    private static func deactivateManagedConstraints(on segmented: NSSegmentedControl, container: NSView) {
        let identifiers = Set(ConstraintIdentifier.allCases.map(\.rawValue))

        let containerConstraints = container.constraints.filter { constraint in
            guard let identifier = constraint.identifier, identifiers.contains(identifier) else { return false }
            let involvesSegmented = (constraint.firstItem as? NSSegmentedControl) === segmented || (constraint.secondItem as? NSSegmentedControl) === segmented
            return involvesSegmented
        }

        let segmentedConstraints = segmented.constraints.filter { constraint in
            guard let identifier = constraint.identifier else { return false }
            return identifiers.contains(identifier)
        }

        NSLayoutConstraint.deactivate(containerConstraints + segmentedConstraints)
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

    private enum ConstraintIdentifier: String, CaseIterable {
        case leading = "UBSegmentedEqualWidthLeading"
        case trailing = "UBSegmentedEqualWidthTrailing"
        case width = "UBSegmentedEqualWidthWidth"
    }
}
#endif
