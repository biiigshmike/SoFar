//
//  SegmentedControl.swift
//  Offshore
//
//  Created by Michael Brown on 9/28/25.
//

import SwiftUI

#if os(macOS)
import AppKit

// This new representable will correctly style our segmented controls.
private struct MacSegmentedControlStyler: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.alphaValue = 0 // Invisible hook
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let control = findSegmentedControl(from: nsView) else { return }

            // Style for modern macOS (pill shape, full width)
            if #available(macOS 13.0, *) {
                control.segmentDistribution = .fillEqually
            }
            control.segmentStyle = .texturedRounded

            // Make it transparent for the Liquid Glass effect
            control.wantsLayer = true
            control.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        return view.superview?.subviews.first { $0 is NSSegmentedControl } as? NSSegmentedControl
    }
}

extension View {
    /// Applies a modern, full-width, pill-shaped style to a Picker on macOS.
    func applyMacSegmentedControlStyle() -> some View {
        self.background(MacSegmentedControlStyler())
    }
}
#endif
