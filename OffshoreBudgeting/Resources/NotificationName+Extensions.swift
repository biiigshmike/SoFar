//
//  NotificationName+Extensions.swift
//  SoFar
//
//  Created by Michael Brown on 8/11/25.
//

import Foundation

// MARK: - App Notification Names
/// Centralized notification names to avoid stringly-typed mistakes.
/// Add new custom Notification.Name constants here as your app grows.
extension Notification.Name {

    // MARK: - dataStoreDidChange
    /// Posted by the app whenever Core Data changes are persisted. Views or
    /// view models can observe this to trigger refreshes.
    ///
    /// Usage:
    /// NotificationCenter.default.post(name: .dataStoreDidChange, object: nil)
    /// NotificationCenter.default.addObserver(forName: .dataStoreDidChange, object: nil, queue: .main) { _ in ... }
    static let dataStoreDidChange = Notification.Name("dataStoreDidChange")
    
    // MARK: - dataStoreDidChangeRemotely
    /// Posted by the app when Core Data’s persistent store reports a remote change
    /// (e.g., via NSPersistentStoreRemoteChange). Views or view models can observe
    /// this to trigger a refresh or refetch.
    ///
    /// Usage:
    /// NotificationCenter.default.post(name: .dataStoreDidChangeRemotely, object: nil)
    /// NotificationCenter.default.addObserver(forName: .dataStoreDidChangeRemotely, object: nil, queue: .main) { _ in ... }
    static let dataStoreDidChangeRemotely = Notification.Name("dataStoreDidChangeRemotely")

    // MARK: - BudgetDetails Add Requests
    /// Posted by HomeView (or other containers) to instruct the embedded
    /// `BudgetDetailsView` to present the add planned expense flow for the
    /// specified budget identifier.
    static let budgetDetailsRequestAddPlannedExpense = Notification.Name("budgetDetailsRequestAddPlannedExpense")

    /// Posted by HomeView (or other containers) to instruct the embedded
    /// `BudgetDetailsView` to present the add variable expense flow for the
    /// specified budget identifier.
    static let budgetDetailsRequestAddVariableExpense = Notification.Name("budgetDetailsRequestAddVariableExpense")
}
