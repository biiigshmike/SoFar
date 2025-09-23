//
//  CardItem+CoreDataBridge.swift
//  SoFar
//
//  Bridges Core Data `Card` objects to your UI model `CardItem` so we
//  can reuse CardTileView anywhere in the app (including pickers).
//
//  Usage:
//    let uiItem = CardItem(from: card) // card: CoreData `Card`
//

import Foundation
import CoreData
import SwiftUI

// MARK: - CardItem + Core Data Bridge
extension CardItem {

    // MARK: init(from:appearanceStore:)
    /// Creates a `CardItem` from a Core Data `Card` object.
    /// - Parameters:
    ///   - managedCard: The Core Data card object to bridge.
    ///   - appearanceStore: Store that provides the theme for a card UUID.
    /// - Discussion:
    ///   Uses the saved per-card theme from `CardAppearanceStore`. If no theme
    ///   has been saved yet, falls back to `.graphite` to guarantee a valid UI.
    @MainActor
    init(from managedCard: Card,
         appearanceStore: CardAppearanceStore? = nil)
    {
        let resolvedAppearanceStore = appearanceStore ?? CardAppearanceStore.shared

        // Pull UUID + name safely from Core Data.
        let cardUUID: UUID = managedCard.value(forKey: "id") as? UUID ?? UUID()
        let cardName: String = managedCard.value(forKey: "name") as? String ?? "Untitled"

        // Resolve persisted theme (fallback to graphite).
        let theme: CardTheme = resolvedAppearanceStore.theme(for: cardUUID)

        // Use the memberwise initializer of `CardItem`.
        self.init(
            objectID: managedCard.objectID,
            uuid: cardUUID,
            name: cardName,
            theme: theme
        )
    }
}
