import SwiftUI

// MARK: - ThemedTextFieldStyle
/// A text field style that applies the current AppTheme colors
/// so text inputs visually match the selected theme.
struct ThemedTextFieldStyle: TextFieldStyle {
    let accent: Color
    let fill: Color

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(8)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent, lineWidth: 1)
            )
    }
}
