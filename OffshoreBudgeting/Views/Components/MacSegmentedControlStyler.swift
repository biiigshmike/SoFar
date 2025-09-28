// OffshoreBudgeting/Views/Components/MacSegmentedControlStyler.swift

import SwiftUI

#if os(macOS)
import AppKit

/// A view modifier that applies a full-width, capsule-style "Liquid Glass"
/// appearance to a segmented `Picker` on macOS.
struct MacSegmentedControlStyler: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        // This modifier applies a background hook to find and style the NSSegmentedControl.
        // It's only active on modern macOS versions that support the glass aesthetic.
        if capabilities.supportsOS26Translucency {
            content
                .background(SegmentedControlConfigurator())
        } else {
            content
        }
    }
}

/// An NSViewRepresentable that finds the underlying NSSegmentedControl
/// and applies custom styling and layout constraints.
private struct SegmentedControlConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // The view is transparent and doesn't interact; it's just a hook.
        view.alphaValue = 0.0
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Defer to the next run loop cycle to ensure the SwiftUI view hierarchy is settled.
        DispatchQueue.main.async {
            applyStyle(from: nsView)
        }
    }

    private func applyStyle(from view: NSView) {
        guard let segmentedControl = findSegmentedControl(from: view) else { return }

        // 1. Apply the modern capsule style for macOS 13+
        if #available(macOS 13.0, *) {
             // This is the key to making the segments expand to fill the control's bounds.
            segmentedControl.segmentDistribution = .fillEqually
        }
        
        // This makes each segment pill-shaped.
        segmentedControl.segmentStyle = .texturedRounded
        
        // 2. Make the background transparent so the underlying GlassCapsuleContainer shows through.
        segmentedControl.wantsLayer = true
        segmentedControl.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 3. Make the control itself expand to fill its container horizontally.
        // This is the crucial step that fixes the centering issue.
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        guard let container = segmentedControl.superview else { return }

        let constraintsId = "mac-segmented-fill-width"
        
        // Deactivate any existing constraints we might have set before to avoid conflicts.
        container.constraints.filter { $0.identifier == constraintsId }.forEach { $0.isActive = false }

        // Add constraints to pin the control to the edges of its container.
        let leading = segmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        let trailing = segmentedControl.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        leading.identifier = constraintsId
        trailing.identifier = constraintsId
        
        NSLayoutConstraint.activate([leading, trailing])
    }

    /// Finds the NSSegmentedControl that is a sibling of this representable view.
    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        // The representable is added as a background, so the NSSegmentedControl is a sibling.
        return view.superview?.subviews.first { $0 is NSSegmentedControl } as? NSSegmentedControl
    }
}
#endif
