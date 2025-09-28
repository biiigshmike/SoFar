import SwiftUI

#if os(macOS)
import AppKit

/// Applies the shared macOS segmented control styling so that the control adapts
/// to Liquid Glass on OS 26 while preserving the classic flat chrome on legacy
/// systems. The modifier relies on `PlatformCapabilities` so it can gracefully
/// fall back when translucency is unavailable.
struct MacSegmentedControlStyleModifier: ViewModifier {
    let capabilities: PlatformCapabilities
    let colorScheme: ColorScheme
    let accentColor: Color
    let legacyBackgroundColor: Color

    func body(content: Content) -> some View {
        content.background(
            SegmentedControlStyler(
                capabilities: capabilities,
                colorScheme: colorScheme,
                accentColor: accentColor,
                legacyBackgroundColor: legacyBackgroundColor
            )
        )
    }
}

extension View {
    func macSegmentedControlStyle(
        capabilities: PlatformCapabilities,
        colorScheme: ColorScheme,
        accentColor: Color,
        legacyBackgroundColor: Color
    ) -> some View {
        modifier(
            MacSegmentedControlStyleModifier(
                capabilities: capabilities,
                colorScheme: colorScheme,
                accentColor: accentColor,
                legacyBackgroundColor: legacyBackgroundColor
            )
        )
    }
}

enum MacSegmentedControlStyleDefaults {
    /// Neutral grey used for legacy macOS segmented controls so that both light
    /// and dark appearances mirror the classic look.
    static var legacyBackground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.18, alpha: 1.0)
                : NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.90, alpha: 1.0)
        })
    }
}

private struct SegmentedControlStyler: NSViewRepresentable {
    let capabilities: PlatformCapabilities
    let colorScheme: ColorScheme
    let accentColor: Color
    let legacyBackgroundColor: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.alphaValue = 0.0
        DispatchQueue.main.async { applyStyle(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { applyStyle(from: nsView) }
    }

    private func applyStyle(from view: NSView) {
        guard let segmented = findSegmentedControl(from: view) else { return }
        configure(segmented)
    }

    private func configure(_ segmented: NSSegmentedControl) {
        if #available(macOS 13.0, *) {
            segmented.segmentDistribution = .fillEqually
        }
        segmented.segmentStyle = .capsule
        segmented.focusRingType = .none
        segmented.appearance = NSAppearance(named: colorScheme == .dark ? .vibrantDark : .vibrantLight)

        segmented.wantsLayer = true
        guard let layer = segmented.layer else { return }

        let cornerRadius = max(segmented.bounds.height / 2, 10)
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true

        if capabilities.supportsOS26Translucency {
            applyTranslucentStyle(to: segmented, layer: layer)
        } else {
            applyLegacyStyle(to: segmented, layer: layer)
        }

        segmented.needsDisplay = true
    }

    private func applyTranslucentStyle(to segmented: NSSegmentedControl, layer: CALayer) {
        segmented.drawsBackground = false
        segmented.isBordered = false

        let borderColor = translucentBorderColor()
        let foreground = translucentForegroundColor()

        layer.backgroundColor = NSColor.clear.cgColor
        layer.borderWidth = 1.0
        layer.borderColor = borderColor.cgColor
        layer.shadowOpacity = 0

        segmented.contentTintColor = foreground
        for index in 0..<segmented.segmentCount {
            segmented.setContentTintColor(foreground, forSegment: index)
        }

        if segmented.responds(to: Selector(("setSelectedSegmentBezelColor:"))) {
            segmented.setValue(NSColor.clear, forKey: "selectedSegmentBezelColor")
        }
    }

    private func applyLegacyStyle(to segmented: NSSegmentedControl, layer: CALayer) {
        segmented.drawsBackground = false
        segmented.isBordered = false

        let fillColor = legacyBackgroundColor(for: colorScheme)
        let borderColor = legacyBorderColor()
        let foreground = legacyForegroundColor()

        layer.backgroundColor = fillColor.cgColor
        layer.borderWidth = 1.0
        layer.borderColor = borderColor.cgColor

        segmented.contentTintColor = foreground
        for index in 0..<segmented.segmentCount {
            segmented.setContentTintColor(foreground, forSegment: index)
        }
    }

    private func translucentBorderColor() -> NSColor {
        let accent = NSColor(accentColor).usingColorSpace(.sRGB) ?? NSColor(calibratedWhite: 0.75, alpha: 1.0)
        let alpha: CGFloat = colorScheme == .dark ? 0.45 : 0.30
        return accent.withAlphaComponent(alpha)
    }

    private func translucentForegroundColor() -> NSColor {
        switch colorScheme {
        case .dark:
            return NSColor(calibratedWhite: 0.94, alpha: 0.95)
        default:
            return NSColor(calibratedWhite: 0.10, alpha: 0.92)
        }
    }

    private func legacyBackgroundColor(for scheme: ColorScheme) -> NSColor {
        let base = NSColor(legacyBackgroundColor).usingColorSpace(.sRGB) ?? NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.90, alpha: 1.0)
        if scheme == .dark {
            return base.blended(withFraction: 0.70, of: NSColor.black) ?? NSColor(calibratedWhite: 0.18, alpha: 1.0)
        } else {
            return base
        }
    }

    private func legacyBorderColor() -> NSColor {
        colorScheme == .dark
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.black.withAlphaComponent(0.12)
    }

    private func legacyForegroundColor() -> NSColor {
        colorScheme == .dark
            ? NSColor(calibratedWhite: 0.92, alpha: 1.0)
            : NSColor(calibratedWhite: 0.15, alpha: 1.0)
    }

    private func findSegmentedControl(from view: NSView) -> NSSegmentedControl? {
        guard let root = view.superview else { return nil }
        return searchSegmented(in: root)
    }

    private func searchSegmented(in node: NSView) -> NSSegmentedControl? {
        for sub in node.subviews {
            if let seg = sub as? NSSegmentedControl { return seg }
            if let match = searchSegmented(in: sub) { return match }
        }
        return nil
    }
}
#endif
