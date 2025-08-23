import SwiftUI

// MARK: - HintBubble
/// Floating bubble used to present contextual hints.
struct HintBubble: View {
    let hint: AppHint
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(hint.title)
                .font(.headline)
            Text(hint.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button(hint.actionTitle, action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }
}
