//
//  CardPickerItemTile.swift
//  SoFar
//
//  Tappable wrapper around CardTileView for horizontal pickers.
//  Renders the exact card styling with a true credit-card aspect ratio.
//
//  Selection: no extra shadows; selection glow is handled by CardTileView.
//

import SwiftUI
import CoreData

// MARK: - CardPickerItemTile
struct CardPickerItemTile: View {

    // MARK: Inputs
    let card: Card
    let isSelected: Bool
    let onTap: () -> Void

    // MARK: Layout Constants
    /// ISO/ID-1 credit card aspect ratio (width / height).
    private let creditCardAspect: CGFloat = 85.60 / 53.98 // ≈ 1.586
    /// Visual height for the picker thumbnail. Adjust to taste.
    private let pickerHeight: CGFloat = 132

    // MARK: Body
    var body: some View {
        let uiItem = CardItem(from: card)

        CardTileView(card: uiItem, showsBaseShadow: false)
            // Keep the *shape* correct first…
            .aspectRatio(creditCardAspect, contentMode: .fit)
            // …then set the height to control the overall size in the row.
            .frame(height: pickerHeight)

            // Clip & hit area match the card’s continuous rounded rect.
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))

            // No additional shadow here; keep tiles flat in pickers.

            // Tap handling
            .onTapGesture(perform: onTap)

            // Accessibility
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(uiItem.name)"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
