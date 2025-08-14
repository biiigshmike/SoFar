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
            .frame(width: 160, height: 100)
            .background(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
