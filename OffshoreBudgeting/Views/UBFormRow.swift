import SwiftUI

/// Ensures form rows render in a single leading-aligned column across platforms.
/// Wrap any solitary field in `UBFormRow` to avoid the trailing "content" column
/// that `Form` can introduce, which otherwise right-aligns controls.
struct UBFormRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
