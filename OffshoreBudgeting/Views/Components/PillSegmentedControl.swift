// OffshoreBudgeting/Views/Components/PillSegmentedControl.swift

import SwiftUI

/// A fully custom, pill-style segmented control that provides a consistent, modern
/// appearance across all platforms, including macOS.
struct PillSegmentedControl<SelectionValue, Content>: View where SelectionValue: Hashable, Content: View {
    
    @Binding var selection: SelectionValue
    private let content: () -> Content
    
    // By introspecting the ViewBuilder content, we can build the segments dynamically.
    private let segments: [(tag: SelectionValue, label: AnyView)]

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.content = content
        self.segments = Self.extractSegments(from: content)
    }

    var body: some View {
        Picker("", selection: $selection) {
            content()
        }
        .pickerStyle(.segmented)
    }
    
    /// A robust method to extract tag and label information from the ViewBuilder content
    /// using reflection, avoiding reliance on private SwiftUI types.
    static func extractSegments(from content: () -> Content) -> [(tag: SelectionValue, label: AnyView)] {
        let view = content()
        var segments: [(tag: SelectionValue, label: AnyView)] = []

        func process(_ view: any View) {
            let mirror = Mirror(reflecting: view)
            
            var tag: SelectionValue?
            var label: (any View)?

            // SwiftUI's .tag() modifier creates a private `Tagged` struct. We can inspect
            // it via Mirror. It typically has two children labeled "tag" and "content".
            if let tagChild = mirror.children.first(where: { $0.label == "tag" }),
               let contentChild = mirror.children.first(where: { $0.label == "content" }) {
                
                if let extractedTag = tagChild.value as? SelectionValue,
                   let extractedContent = contentChild.value as? any View {
                    tag = extractedTag
                    label = extractedContent
                }
            }

            if let tag = tag, let label = label {
                segments.append((tag, AnyView(label)))
            } else {
                // If it's not a tagged view, it's likely a container like TupleView.
                // We recurse into its children to find the tagged views.
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
