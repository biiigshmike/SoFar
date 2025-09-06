//
//  SelectCard.swift
//  SoFar
//
//  A simple selectable tile used in horizontal pickers (budgets, cards, etc.)
//  - Parameters:
//    - title: Display text
//    - isSelected: Draws an accent border + tint when true
//

import SwiftUI

struct SelectCard: View {
    // MARK: Inputs
    let title: String
    let isSelected: Bool

    // MARK: Body
    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .multilineTextAlignment(.center)
            // Size: Slightly smaller on macOS to avoid overly large tiles in sheets.
            // On iOS/tvOS we keep the original 160×100 footprint.
            .frame(
                width: {
                    #if os(macOS)
                    return 150
                    #else
                    return 160
                    #endif
                }(),
                height: {
                    #if os(macOS)
                    return 90
                    #else
                    return 100
                    #endif
                }()
            )
            // Use a custom neutral fill instead of `.thinMaterial` so cards look
            // consistent across platforms. `.thinMaterial` can appear opaque gray
            // on macOS and may not match the form background.
            .background(DS.Colors.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
