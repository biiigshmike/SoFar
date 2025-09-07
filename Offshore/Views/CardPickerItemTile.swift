//
//  CardPickerItemTile.swift
//  SoFar
//
//  Tappable wrapper around CardTileView for horizontal pickers.
//  Renders the exact card styling with a true credit-card aspect ratio.
//
//  Selection: uses an optional subtle shadow (no borders).
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
    /// We reduce the height slightly on macOS to avoid an oversized row.
    #if os(macOS)
    private let pickerHeight: CGFloat = 120
    #else
    private let pickerHeight: CGFloat = 132
    #endif

    // MARK: Body
    var body: some View {
        let uiItem = CardItem(from: card)

        CardTileView(card: uiItem)
            // Keep the *shape* correct first…
            .aspectRatio(creditCardAspect, contentMode: .fit)
            // …then set the height to control the overall size in the row.
            .frame(height: pickerHeight)

            // Clip & hit area match the card’s continuous rounded rect.
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))

            // Optional, subtle selection cue (no borders).
            .shadow(radius: isSelected ? 10 : 0, y: isSelected ? 2 : 0)

            // Tap handling
            .onTapGesture(perform: onTap)

            // Accessibility
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(uiItem.name)"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
