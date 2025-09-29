//
//  HomeViewHelpers.swift
//  Offshore
//
//  Created by Michael Brown on 9/28/25.
//

import SwiftUI
import UIKit

// MARK: - Home Header Summary
struct HomeHeaderContextSummary: View {
    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(primaryTitle)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(secondaryDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryTitle: String {
        summary.budgetName
    }

    private var secondaryDetail: String {
        summary.periodString
    }
}


// MARK: - Header Control Width Matching

struct HomeHeaderMatchedWidthModifier: ViewModifier {
    let intrinsicWidth: Binding<CGFloat?>
    let matchedWidth: CGFloat?
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        content
            .background(
                HomeHeaderControlWidthReporter(intrinsicWidth: intrinsicWidth)
            )
            .frame(width: resolvedWidth)
    }

    private var resolvedWidth: CGFloat? {
        let minimum = minimumWidth
        let intrinsic = intrinsicWidth.wrappedValue ?? 0

        if let matchedWidth, matchedWidth > 0 {
            return max(max(matchedWidth, intrinsic), minimum)
        }

        if intrinsic > 0 { return max(intrinsic, minimum) }
        return nil
    }

    private var minimumWidth: CGFloat {
        RootHeaderActionMetrics.minimumGlassWidth(for: capabilities)
    }
}

struct HomeHeaderControlWidthReporter: View {
    let intrinsicWidth: Binding<CGFloat?>

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: HomeHeaderControlWidthKey.self, value: proxy.size.width)
                .onAppear { updateIntrinsicWidth(proxy.size.width) }
                .ub_onChange(of: proxy.size.width) { newWidth in
                    updateIntrinsicWidth(newWidth)
                }
        }
    }

    private func updateIntrinsicWidth(_ width: CGFloat) {
        let binding = intrinsicWidth
        DispatchQueue.main.async {
            let quantized = (width * 2).rounded() / 2 // 0.5pt steps
            let old = binding.wrappedValue ?? 0
            let tolerance: CGFloat = 0.5
            if abs(old - quantized) > tolerance {
                binding.wrappedValue = quantized
            }
        }
    }
}

struct HomeHeaderControlWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func homeHeaderMatchedControlWidth(
        intrinsicWidth: Binding<CGFloat?>,
        matchedWidth: CGFloat?
    ) -> some View {
        modifier(
            HomeHeaderMatchedWidthModifier(
                intrinsicWidth: intrinsicWidth,
                matchedWidth: matchedWidth
            )
        )
    }

    func homeHeaderMinMatchedWidth(
        intrinsicWidth: Binding<CGFloat?>,
        matchedWidth: CGFloat?
    ) -> some View {
        modifier(
            HomeHeaderMinWidthModifier(
                intrinsicWidth: intrinsicWidth,
                matchedWidth: matchedWidth
            )
        )
    }
}

private struct HomeHeaderMinWidthModifier: ViewModifier {
    let intrinsicWidth: Binding<CGFloat?>
    let matchedWidth: CGFloat?
    @Environment(\.platformCapabilities) private var capabilities

    func body(content: Content) -> some View {
        content
            .background(
                HomeHeaderControlWidthReporter(intrinsicWidth: intrinsicWidth)
            )
            .frame(minWidth: resolvedMinWidth)
    }

    private var resolvedMinWidth: CGFloat? {
        let minimum = minimumWidth
        let intrinsic = intrinsicWidth.wrappedValue ?? 0
        let matched = matchedWidth ?? 0
        let base = max(intrinsic, matched, minimum)
        return base > 0 ? base : nil
    }

    private var minimumWidth: CGFloat {
        RootHeaderActionMetrics.minimumGlassWidth(for: capabilities)
    }
}


// MARK: - Header Action Helpers
struct HideMenuIndicatorIfPossible: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macCatalyst 16.0, *) {
            content.menuIndicator(.hidden)
        } else {
            content
        }
    }
}

struct FilterBar: View {
    @Binding var sort: BudgetDetailsViewModel.SortOption
    @Binding var segment: BudgetDetailsViewModel.Segment
    let onSegmentChanged: (BudgetDetailsViewModel.Segment) -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            PillSegmentedControl(selection: $segment) {
                Text("Planned Expenses").tag(BudgetDetailsViewModel.Segment.planned)
                Text("Variable Expenses").tag(BudgetDetailsViewModel.Segment.variable)
            }
            .ub_onChange(of: segment) { newValue in
                onSegmentChanged(newValue)
            }
            
            PillSegmentedControl(selection: $sort) {
                Text("A–Z").tag(BudgetDetailsViewModel.SortOption.titleAZ)
                Text("$↓").tag(BudgetDetailsViewModel.SortOption.amountLowHigh)
                Text("$↑").tag(BudgetDetailsViewModel.SortOption.amountHighLow)
                Text("Date ↑").tag(BudgetDetailsViewModel.SortOption.dateOldNew)
                Text("Date ↓").tag(BudgetDetailsViewModel.SortOption.dateNewOld)
            }
        }
    }
}
