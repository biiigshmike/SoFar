//
//  AddIncomeFormView+Lifecycle.swift
//  SoFar
//
//  Created by Michael Brown on 8/13/25.
//

import SwiftUI
import CoreData

// MARK: - Eager Load Existing Income On Appear
extension AddIncomeFormView {
    /// Ensures existing income (when editing) populates VM before form shows.
    /// Also pre-fills the First Date when adding and an initial date is provided.
    @ViewBuilder
    var _eagerLoadHook: some View {
        Color.clear
            .frame(height: 0)
            .onAppear {
                do { try viewModel.loadIfNeeded(from: viewContext) }
                catch { /* ignore; handled at save time */ }
                // Pre-fill first date when adding a new income and an initialDate was provided.
                if !viewModel.isEditing, let prefill = initialDate {
                    viewModel.firstDate = prefill
                }
            }
    }
}
