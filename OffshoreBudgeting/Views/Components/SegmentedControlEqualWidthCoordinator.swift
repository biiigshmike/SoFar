#if os(macOS)
import AppKit

struct SegmentedControlEqualWidthCoordinator {
    // MARK: - Constraint Identifiers
    private static let leadingConstraintIdentifier = "SegmentedControlEqualWidthCoordinator.leading"
    private static let trailingConstraintIdentifier = "SegmentedControlEqualWidthCoordinator.trailing"

    // MARK: - Equal Width Enforcement
    static func enforceEqualWidth(for control: NSSegmentedControl) {
        if #available(macOS 13.0, *) {
            control.segmentDistribution = .fillEqually
        }

        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        guard let container = control.superview else { return }

        if control.translatesAutoresizingMaskIntoConstraints {
            control.translatesAutoresizingMaskIntoConstraints = false
        }

        ensureConstraint(
            identifier: leadingConstraintIdentifier,
            control: control,
            container: container
        ) { control, container in
            control.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        }

        ensureConstraint(
            identifier: trailingConstraintIdentifier,
            control: control,
            container: container
        ) { control, container in
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        }

        container.layoutSubtreeIfNeeded()
    }

    // MARK: - Constraint Helpers
    private static func ensureConstraint(
        identifier: String,
        control: NSSegmentedControl,
        container: NSView,
        builder: (NSSegmentedControl, NSView) -> NSLayoutConstraint
    ) {
        if let existing = container.constraints.first(where: { constraint in
            guard constraint.identifier == identifier else { return false }
            return (constraint.firstItem as? NSSegmentedControl) === control ||
                (constraint.secondItem as? NSSegmentedControl) === control
        }) {
            if !existing.isActive {
                existing.isActive = true
            }
            return
        }

        let constraint = builder(control, container)
        constraint.identifier = identifier
        constraint.priority = .defaultHigh
        constraint.isActive = true
    }
}
#else
struct SegmentedControlEqualWidthCoordinator {
    static func enforceEqualWidth(for control: AnyObject) {}
}
#endif
