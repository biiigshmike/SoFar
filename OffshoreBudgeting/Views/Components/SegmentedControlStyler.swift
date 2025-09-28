//
//  SegmentedControlStyler.swift
//  Offshore
//
//  Created by Michael Brown on 9/28/25.
//

import SwiftUI

#if os(macOS)
import AppKit

/// A view modifier that applies a full-width, capsule-style "Liquid Glass"
/// appearance to a segmented `Picker` on modern macOS.
struct SegmentedControlStyler: ViewModifier {
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        // We apply the styler via a background so it doesn't affect the SwiftUI layout proposals.
        // This is a robust way to inject AppKit code.
        content.background(StylerView(isModern: capabilities.supportsOS26Translucency))
    }

    private struct StylerView: NSViewRepresentable {
        let isModern: Bool

        func makeNSView(context: Context) -> NSView {
            return NSView() // Invisible hook view.
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                guard let segmentedControl = findSegmentedControl(from: nsView) else { return }
                applyStyle(to: segmentedControl)
            }
        }

        /// Finds the NSSegmentedControl that is a sibling of this representable view.
        private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
            return view.superview?.subviews.first { $0 is NSSegmentedControl } as? NSSegmentedControl
        }

        private func applyStyle(to control: NSSegmentedControl) {
            // --- 1. Sizing and Layout ---
            // This is the key to making the control fill the width and have proportional segments.
            if #available(macOS 13.0, *) {
                control.segmentDistribution = .fillEqually
            }

            // --- 2. Shape and Appearance ---
            if isModern {
                // This is the modern style that creates the pill/capsule shape.
                control.segmentStyle = .texturedRounded
            } else {
                // For legacy macOS, a simpler rounded style is appropriate.
                control.segmentStyle = .rounded
            }

            // --- 3. Transparency for Liquid Glass ---
            // Making the control's background clear allows the GlassCapsuleContainer to show through.
            if isModern {
                 if let cell = control.cell as? NSSegmentedCell {
                    cell.backgroundColor = .clear
                }
            }
        }
    }
}

extension View {
    /// Applies a modifier to style a segmented Picker for a full-width,
    /// capsule-style "Liquid Glass" look on modern macOS. Falls back gracefully on older versions.
    func macOSSegmentedControlStyle() -> some View {
        #if os(macOS)
        return self.modifier(SegmentedControlStyler())
        #else
        return self
        #endif
    }
}
#else
// On non-macOS platforms, this modifier does nothing.
extension View {
    func macOSSegmentedControlStyle() -> some View {
        return self
    }
}
#endif
