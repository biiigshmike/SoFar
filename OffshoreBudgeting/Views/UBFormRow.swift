import SwiftUI

/// Ensures form rows render in a single leading-aligned column on macOS.
/// Wrap any solitary field in `UBFormRow` to avoid the trailing "content" column
/// that `Form` uses on macOS, which otherwise right-aligns controls.
struct UBFormRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // Place the content in a stretching container so controls fill
        // the available width and stay pinned to the leading edge on macOS.
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
