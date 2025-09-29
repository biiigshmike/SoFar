// OffshoreBudgeting/Views/Components/PeriodNavigationControl.swift

import SwiftUI

/// Chevron-based navigation control for traversing budgeting periods.
struct PeriodNavigationControl: View {
    @Environment(\.platformCapabilities) private var capabilities
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private let title: String
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    init(
        title: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.title = title
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            navigationButton(systemName: "chevron.left", accessibilityLabel: "Previous", action: onPrevious)

            Text(title)
                .font(titleTypography.font)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(titleTypography.minimumScaleFactor)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(1)

            navigationButton(systemName: "chevron.right", accessibilityLabel: "Next", action: onNext)
        }
    }

    @ViewBuilder
    private func navigationButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        RootHeaderIconActionButton(
            systemImage: systemName,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
    }

    private struct TitleTypography {
        let font: Font
        let minimumScaleFactor: CGFloat
    }

    private var titleTypography: TitleTypography {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return TitleTypography(font: .title3.bold(), minimumScaleFactor: 0.6)
        }
        #endif
        return TitleTypography(font: .title2.bold(), minimumScaleFactor: 0.7)
    }
}
