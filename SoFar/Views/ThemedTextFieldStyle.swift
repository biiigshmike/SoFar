import SwiftUI

/// A text field style that draws a rounded border using the app's accent color.
struct ThemedTextFieldStyle: TextFieldStyle {
    /// Color used for the border stroke.
    var accentColor: Color

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor, lineWidth: 1)
            )
    }
}
