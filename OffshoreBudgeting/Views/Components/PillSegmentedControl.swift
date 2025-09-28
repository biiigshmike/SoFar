//
//  PillSegmentedControl.swift
//  Offshore
//
//  Created by Michael Brown on 9/28/25.
//

// OffshoreBudgeting/Views/Components/PillSegmentedControl.swift

import SwiftUI

/// A fully custom, pill-style segmented control that mimics the modern iOS aesthetic.
/// It is platform-aware, using this custom style on macOS and the native `.pickerStyle(.segmented)` on iOS.
struct PillSegmentedControl<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    
    @Binding var selection: SelectionValue
    private let content: () -> Content

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.content = content
    }

    var body: some View {
        #if os(macOS)
        // On macOS, we use our custom-built picker to achieve the desired iOS look.
        CustomMacPillPicker(selection: $selection, content: content)
        #else
        // On iOS, the native picker is already perfect.
        Picker("", selection: $selection) {
            content()
        }
        .pickerStyle(.segmented)
        #endif
    }
}

#if os(macOS)
/// The custom SwiftUI implementation for the pill-style picker on macOS.
private struct CustomMacPillPicker<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selection: SelectionValue
    
    // This helper extracts the necessary info (tag and label) from the Picker's content.
    private let segments: [(tag: SelectionValue, label: AnyView)]

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.segments = Self.extractSegments(from: content)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.tag) { segment in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = segment.tag
                    }
                }) {
                    segment.label
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .background {
                    if selection == segment.tag {
                        Capsule()
                            .fill(selectionIndicatorColor)
                            .matchedGeometryEffect(id: "selectionIndicator", in: namespace, isSource: true)
                    }
                }
            }
        }
        .background(backgroundMaterial, in: Capsule())
    }

    @Namespace private var namespace

    private var backgroundMaterial: some ShapeStyle {
        if capabilities.supportsOS26Translucency {
            return AnyShapeStyle(.ultraThinMaterial)
        } else {
            return AnyShapeStyle(themeManager.selectedTheme.secondaryBackground)
        }
    }
    
    private var selectionIndicatorColor: Color {
        if capabilities.supportsOS26Translucency {
            return .primary.opacity(0.12)
        } else {
            return .primary.opacity(0.08)
        }
    }
    
    /// A robust method to extract tag and label information from the ViewBuilder content.
    static func extractSegments(from content: () -> Content) -> [(tag: SelectionValue, label: AnyView)] {
        let view = content()
        var segments: [(tag: SelectionValue, label: AnyView)] = []

        func process(_ view: any View) {
            if let taggedView = view as? any TaggedView, let tag = taggedView.tag as? SelectionValue {
                segments.append((tag, AnyView(taggedView.label)))
            } else if let forEach = view as? ForEach<Data, ID, Content> {
                 // Handle ForEach if needed, though not required for your current implementation.
            } else {
                // Fallback for TupleViews which group multiple views.
                let mirror = Mirror(reflecting: view)
                for child in mirror.children {
                    if let childView = child.value as? any View {
                        process(childView)
                    }
                }
            }
        }
        process(view)
        return segments
    }
}

// Helper protocols to introspect SwiftUI views and get their tag/label.
private protocol TaggedView {
    var tag: AnyHashable { get }
    var label: any View { get }
}
extension Tagged: TaggedView {}
#endif
