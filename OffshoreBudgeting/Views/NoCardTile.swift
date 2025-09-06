//
//  NoCardTile.swift
//  SoFar
//
//  Placeholder card tile used when a card is optional.
//

import SwiftUI

struct NoCardTile: View {
    // MARK: Inputs
    let isSelected: Bool
    /// Optional tap callback so the tile can be used like a button.
    var onTap: (() -> Void)? = nil

    // MARK: Layout
    /// ISO/ID-1 credit card aspect ratio (width / height).
    private let aspectRatio: CGFloat = 85.60 / 53.98 // ≈ 1.586

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Colors.cardFill)
                Text("No Card")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityLabel(Text("No Card\(isSelected ? ", selected" : "")"))
        .accessibilityHint(Text("Tap to select no card"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

