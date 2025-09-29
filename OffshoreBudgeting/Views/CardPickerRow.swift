//
//  CardPickerRow.swift
//  SoFar
//
//  Horizontal, scrollable row of saved cards rendered with CardTileView styling.
//  Designed for AddUnplannedExpenseView (or anywhere you pick a card).
//
//  Parameters:
//  - allCards: Core Data cards `[Card]` (we bridge each to `CardItem` internally).
//  - selectedCardID: Two-way binding to the picked card's `NSManagedObjectID?`.
//
//  Behavior:
//  - Shows the actual themed card tiles with a strong color-matched selection ring + glow.
//  - On first appear, auto-selects the first card if nothing is chosen yet.
//  - Keeps selection stable via Core Data `objectID`.
//
//  How to use:
//    CardPickerRow(allCards: vm.allCards, selectedCardID: $vm.selectedCardID)
//

import SwiftUI
import CoreData

// MARK: - CardPickerRow
struct CardPickerRow: View {

    // MARK: Inputs
    /// Core Data Card entities to render as selectable tiles.
    let allCards: [Card]

    /// Selected Core Data objectID; keeps selection stable even through renames.
    @Binding var selectedCardID: NSManagedObjectID?

    /// When true, show a "No Card" option and do **not** auto-select the first card.
    /// Useful for forms where assigning a card is optional (e.g., planned expenses).
    var includeNoneTile: Bool = false

    // MARK: Layout
    // Card tile height. Adjust here rather than inside individual views so
    // tweaks remain consistent across the app.
    private let tileHeight: CGFloat = 160

    // MARK: Body
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DS.Spacing.l) {
                if includeNoneTile {
                    NoCardTile(isSelected: selectedCardID == nil)
                        .frame(height: tileHeight)
                        .onTapGesture { selectedCardID = nil }
                }
                ForEach(allCards, id: \.objectID) { managedCard in
                    // MARK: Bridge Core Data → UI model
                    // Uses your existing CoreDataBridge to pull name/theme.
                    let item = CardItem(from: managedCard)

                    CardTileView(
                        card: item,
                        isSelected: selectedCardID == managedCard.objectID
                    ) {
                        // MARK: On Tap → Select for Expense
                        selectedCardID = managedCard.objectID
                    }
                    .frame(height: tileHeight)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
        }
        // Apply unified background and hide indicators across platforms
        .ub_pickerBackground()
        .ub_hideScrollIndicators()
        // Default to the first available card if none selected yet and no "None" option.
        .onAppear {
            if !includeNoneTile,
               selectedCardID == nil,
               let firstID = allCards.first?.objectID {
                selectedCardID = firstID
            }
        }
    }
}
