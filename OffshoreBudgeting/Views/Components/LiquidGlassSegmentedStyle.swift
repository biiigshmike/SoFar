import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - LiquidGlassSegmentedStyle
struct LiquidGlassSegmentedStyle: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        let accent = themeManager.selectedTheme.glassPalette.accent
#if os(macOS)
        if capabilities.supportsOS26Translucency {
            if #available(macOS 26.0, *) {
                content
                    .background(MacSegmentedControlStyler(accentColor: accent))
            } else {
                content
                    .controlSize(.large)
                    .tint(accent)
            }
        } else {
            content
                .controlSize(.large)
                .tint(accent)
        }
#else
        content
            .tint(accent)
            .background(UIKitSegmentedControlStyler(accentColor: accent, supportsGlass: capabilities.supportsOS26Translucency))
#endif
    }
}

extension View {
    func liquidGlassSegmentedStyle() -> some View {
        modifier(LiquidGlassSegmentedStyle())
    }
}

#if os(macOS)
@available(macOS 26.0, *)
private struct MacSegmentedControlStyler: NSViewRepresentable {
    let accentColor: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        DispatchQueue.main.async {
            update(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            update(nsView)
        }
    }

    private func update(_ hostingView: NSView) {
        guard let control = hostingView.enclosingSegmentedControl() else { return }
        style(control)
    }

    private func style(_ control: NSSegmentedControl) {
        control.segmentDistribution = .fillEqually
        control.segmentStyle = .automatic
        control.focusRingType = .default
        control.wantsLayer = true
        control.layer?.cornerCurve = .continuous
        control.layer?.cornerRadius = control.bounds.height / 2
        control.layer?.masksToBounds = true
        applyTint(to: control)
    }

    private func applyTint(to control: NSSegmentedControl) {
        let tint = NSColor(accentColor)
        control.contentTintColor = tint
        control.layer?.backgroundColor = tint.withAlphaComponent(0.16).cgColor
        control.layer?.borderColor = tint.withAlphaComponent(0.25).cgColor
        control.layer?.borderWidth = 0.5
    }
}

@available(macOS 26.0, *)
private extension NSView {
    func enclosingSegmentedControl() -> NSSegmentedControl? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSSegmentedControl }
            .first
    }
}
#else
private struct UIKitSegmentedControlStyler: UIViewRepresentable {
    let accentColor: Color
    let supportsGlass: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        DispatchQueue.main.async {
            update(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            update(uiView)
        }
    }

    private func update(_ hostingView: UIView) {
        guard let control = hostingView.enclosingSegmentedControl() else { return }
        style(control)
    }

    private func style(_ control: UISegmentedControl) {
        let tint = UIColor(accentColor)
        control.selectedSegmentTintColor = supportsGlass ? tint.withAlphaComponent(0.22) : tint
        control.backgroundColor = supportsGlass ? tint.withAlphaComponent(0.10) : nil
        control.layer.cornerCurve = .continuous
        control.layer.cornerRadius = control.bounds.height / 2
        control.layer.masksToBounds = true
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.white
        ], for: .selected)
        control.setTitleTextAttributes([
            .foregroundColor: supportsGlass ? tint.withAlphaComponent(0.75) : tint
        ], for: .normal)
    }
}

private extension UIView {
    func enclosingSegmentedControl() -> UISegmentedControl? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? UISegmentedControl }
            .first
    }
}
#endif
