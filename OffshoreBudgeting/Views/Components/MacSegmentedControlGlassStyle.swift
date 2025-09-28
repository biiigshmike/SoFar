////
////  MacSegmentedControlGlassStyle.swift
////  Offshore
////
////  Created by Michael Brown on 9/28/25.
////
//
////
////  MacSegmentedControlGlassStyle.swift
////  Offshore
////
////  Created by Michael Brown on 9/28/25.
////
//
////
////  MacSegmentedControlGlassStyle.swift
////  Offshore
////
////  Created by Michael Brown on 9/28/25.
////
//
//import SwiftUI
//
//#if os(macOS)
//import AppKit
//
///// A view modifier that applies a full-width, capsule-style "Liquid Glass"
///// appearance to a segmented `Picker` on macOS.
//struct MacSegmentedControlGlassStyle: ViewModifier {
//    @Environment(\.platformCapabilities) private var capabilities
//
//    func body(content: Content) -> some View {
//        // On modern macOS, we apply a custom background to get the correct
//        // sizing and styling. On older versions, we do nothing to preserve
//        // the classic system look.
//        if capabilities.supportsOS26Translucency {
//            content
//                .background(MacSegmentedControlStyler())
//        } else {
//            content
//        }
//    }
//}
//
///// An NSViewRepresentable that finds the underlying NSSegmentedControl
///// and applies custom styling and layout constraints.
//private struct MacSegmentedControlStyler: NSViewRepresentable {
//    func makeNSView(context: Context) -> NSView {
//        let view = NSView()
//        // The view is transparent and doesn't interact; it's just a hook.
//        view.alphaValue = 0.0
//        return view
//    }
//
//    func updateNSView(_ nsView: NSView, context: Context) {
//        // On the next run loop cycle, find the sibling NSSegmentedControl and style it.
//        DispatchQueue.main.async {
//            applyStyle(from: nsView)
//        }
//    }
//
//    private func applyStyle(from view: NSView) {
//        guard let segmentedControl = findSegmentedControl(from: view) else { return }
//
//        // 1. Apply the modern capsule style
//        if #available(macOS 13.0, *) {
//             // Forcing .fillEqually is key to making the segments expand.
//            segmentedControl.segmentDistribution = .fillEqually
//        }
//        
//        // This makes each segment pill-shaped.
//        segmentedControl.segmentStyle = .texturedRounded
//
//        // 2. Ensure the control expands to fill its container horizontally
//        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
//        guard let container = segmentedControl.superview else { return }
//
//        // Deactivate any conflicting constraints we might have set before.
//        container.constraints.filter {
//            $0.identifier == "mac-segmented-fill-width"
//        }.forEach { $0.isActive = false }
//
//        // Add constraints to pin the control to the edges of its container.
//        let leading = segmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor)
//        let trailing = segmentedControl.trailingAnchor.constraint(equalTo: container.trailingAnchor)
//        leading.identifier = "mac-segmented-fill-width"
//        trailing.identifier = "mac-segmented-fill-width"
//        
//        NSLayoutConstraint.activate([leading, trailing])
//    }
//
//    /// Finds the NSSegmentedControl that is a sibling of this representable view.
//    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
//        return view.superview?.subviews.first { $0 is NSSegmentedControl } as? NSSegmentedControl
//    }
//}
//
//extension View {
//    /// Applies a modifier to style a segmented Picker for a full-width,
//    /// capsule-style "Liquid Glass" look on modern macOS.
//    func macOSSegmentedControlGlassStyle() -> some View {
//        modifier(MacSegmentedControlGlassStyle())
//    }
//}
//
//#endif
