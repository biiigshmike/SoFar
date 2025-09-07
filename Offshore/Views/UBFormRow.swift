import SwiftUI

/// Ensures form rows render in a single leading-aligned column on macOS.
/// Wrap any solitary field in `UBFormRow` to avoid the trailing "content" column
/// that `Form` uses on macOS, which otherwise right-aligns controls.
struct UBFormRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS)
        // macOS `Form` renders two columns (label / content) and will place
        // solitary views in the trailing "content" column which right-aligns
        // controls.  By using `LabeledContent` with an empty trailing column we
        // force our field into the leading slot and avoid the unwanted
        // right‑alignment.  Other platforms don't exhibit this behaviour, so we
        // keep the lightweight `HStack` there.
        LabeledContent {
            EmptyView()
        } label: {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        HStack(alignment: .center) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}
