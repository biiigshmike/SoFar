import SwiftUI

/// Ensures form rows render in a single leading-aligned column on macOS.
/// Wrap any solitary field in `UBFormRow` to avoid the trailing "content" column
/// that `Form` uses on macOS, which otherwise right-aligns controls.
struct UBFormRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
#if os(macOS)
        // On macOS, the default form row style can right-align controls.
        // Applying a plain text field style forces leading alignment and
        // removes the extra trailing "value" column behavior.
        .textFieldStyle(.plain)
#endif
    }
}
