// OffshoreBudgeting/Views/Components/PlatformAwareSegmentedPicker.swift

import SwiftUI

/// A picker that displays as a full-width, pill-style segmented control on modern macOS,
/// while using the native SwiftUI Picker on iOS and other platforms.
struct PlatformAwareSegmentedPicker<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    
    @Binding var selection: SelectionValue
    private let content: () -> Content

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.content = content
    }

    var body: some View {
        #if os(macOS)
        // On macOS, we use our custom-built picker to achieve the desired iOS look.
        CustomMacSegmentedPicker(selection: $selection, content: content)
        #else
        // On iOS and other platforms, the native picker already looks great.
        Picker("", selection: $selection) {
            content()
        }
        .pickerStyle(.segmented)
        #endif
    }
}

#if os(macOS)
/// A fully custom segmented control for macOS, built in SwiftUI to mimic the iOS "Liquid Glass" style.
private struct CustomMacSegmentedPicker<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    @Environment(\.platformCapabilities) private var capabilities
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selection: SelectionValue
    
    // We need to extract the tags and labels from the content closure.
    private let segments: [(tag: SelectionValue, label: AnyView)]

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        
        // This is a helper to extract the necessary info from the Picker's content.
        let views = Mirror(reflecting: content()).children.compactMap { $0.value as? TupleView<(some View)> }
        var extractedSegments: [(tag: SelectionValue, label: AnyView)] = []
        for viewTuple in views {
            let viewMirror = Mirror(reflecting: viewTuple.value)
            for child in viewMirror.children {
                if let taggedView = child.value as? any TaggedView, let tag = taggedView.tag as? SelectionValue {
                    extractedSegments.append((tag, AnyView(taggedView.label)))
                }
            }
        }
        self.segments = extractedSegments
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.tag) { segment in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = segment.tag
                    }
                }) {
                    segment.label
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .background {
                    // Show a selection indicator behind the selected segment.
                    if selection == segment.tag {
                        Capsule()
                            .fill(selectionIndicatorColor)
                            .matchedGeometryEffect(id: "selectionIndicator", in: namespace)
                    }
                }
            }
        }
        .background(backgroundMaterial, in: Capsule())
    }

    @Namespace private var namespace

    private var backgroundMaterial: some ShapeStyle {
        if capabilities.supportsOS26Translucency {
            return .ultraThinMaterial
        } else {
            return AnyShapeStyle(themeManager.selectedTheme.secondaryBackground)
        }
    }
    
    private var selectionIndicatorColor: Color {
        if capabilities.supportsOS26Translucency {
            return .primary.opacity(0.15)
        } else {
            return .primary.opacity(0.1)
        }
    }
}

// Helper protocols to extract tag and label from SwiftUI's internal view structure.
private protocol TaggedView {
    var tag: AnyHashable { get }
    var label: any View { get }
}
extension Tagged: TaggedView {}

#endif
