import SwiftUI

// MARK: - Segmented Control Sizing Helpers
extension View {
    /// Expands the view to fill the available horizontal space, ensuring that
    /// segmented control labels adopt equal widths when paired with
    /// `equalWidthSegments()`.
    func segmentedFill() -> some View {
        frame(maxWidth: .infinity)
    }

    /// Applies a background coordinator that enforces equal-width segments for
    /// segmented controls on iOS and macOS while remaining a no-op elsewhere.
    func equalWidthSegments() -> some View {
        modifier(UBEqualWidthSegmentsModifier())
    }
}

private struct UBEqualWidthSegmentsModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.background(UBEqualWidthSegmentApplier())
#elseif os(macOS)
        content.background(UBEqualWidthSegmentApplier())
#else
        content
#endif
    }
}

#if os(iOS)
import UIKit

private struct UBEqualWidthSegmentApplier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: uiView) }
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
            if let segmented = candidate as? UISegmentedControl { return segmented }
            current = candidate.superview
        }
        return nil
    }
}
#elseif os(macOS)
import AppKit

private struct UBEqualWidthSegmentApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0.0
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { applyEqualWidthIfNeeded(from: nsView) }
    }

    private func applyEqualWidthIfNeeded(from view: NSView) {
        guard let segmented = findSegmentedControl(from: view) else { return }
        SegmentedControlEqualWidthCoordinator.enforceEqualWidth(for: segmented)
    }

    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        guard let root = view.superview else { return nil }
        return searchSegmented(in: root)
    }

    private func searchSegmented(in node: NSView) -> NSSegmentedControl? {
        for sub in node.subviews {
            if let seg = sub as? NSSegmentedControl { return seg }
            if let found = searchSegmented(in: sub) { return found }
        }
        return nil
    }
}
#endif
