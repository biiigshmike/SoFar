//
//  RenameCardSheet.swift
//  SoFar
//
//  Minimal rename UI used by CardsView.
//  Now standardized via EditSheetScaffold.
//

import SwiftUI

// MARK: - RenameCardSheet
/// Simple sheet with a text field to rename a card.
/// - Parameters:
///   - originalName: Prefills the field.
///   - onSave: Callback with the new name when user taps Save.
struct RenameCardSheet: View {
    let originalName: String
    var onSave: (String) -> Void

    // MARK: State
    @State private var name: String = ""

    // MARK: body
    var body: some View {
        EditSheetScaffold(
            title: "Rename Card",
            detents: [.fraction(0.25), .medium], // Prefer the compact first snap like your screenshots
            isSaveEnabled: !trimmedName.isEmpty,
            onSave: {                                // Return true to dismiss, false to stay open
                guard !trimmedName.isEmpty else { return false }
                onSave(trimmedName)
                return true
            }
        ) {
            // MARK: Name field
            UBFormRow {
                TextField(
                    "", text: $name,
                    prompt: Text("Card Name"))
                    .ub_noAutoCapsAndCorrection()
                    .multilineTextAlignment(.leading)
                    .onAppear { name = originalName }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Helpers
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
