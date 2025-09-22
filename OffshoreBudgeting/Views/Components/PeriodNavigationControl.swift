import SwiftUI

/// Chevron-based navigation control for traversing budgeting periods.
///
/// Displays backward/forward buttons around a centered title. The control
/// mirrors the layout previously embedded within ``HomeView`` so both platforms
/// share a consistent period navigation experience.
struct PeriodNavigationControl: View {
    // MARK: - Properties
    private let title: String
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    // MARK: - Init
    init(
        title: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }
}
