import Foundation
import Testing
@testable import Offshore

@MainActor
struct ExpenseCategoryServiceTests {

    private func freshService() throws -> ExpenseCategoryService {
        _ = try TestUtils.resetStore()
        return ExpenseCategoryService()
    }

    @Test
    func create_fetch_update_delete_category() throws {
        let service = try freshService()
        let baseline = try service.fetchAllCategories().count

        // Use unique names to avoid collisions with other tests' data
        let groceriesName = "Groceries-\(UUID().uuidString)"
        let utilitiesName = "Utilities-\(UUID().uuidString)"

        // Create
        let cat = try service.addCategory(name: groceriesName, color: "#00FF00")
        #expect(cat.name == groceriesName)
        #expect(cat.color == "#00FF00")

        // Fetch all (sorted)
        _ = try service.addCategory(name: utilitiesName, color: "#0000FF")
        let all = try service.fetchAllCategories(sortedByName: true)
        let names = all.map { $0.name ?? "" }
        #expect(names.contains(groceriesName))
        #expect(names.contains(utilitiesName))

        // Find by ID
        let found = try service.findCategory(byID: cat.id!)
        #expect(found?.objectID == cat.objectID)

        // Find by name
        let byName = try service.findCategory(named: groceriesName)
        #expect(byName?.objectID == cat.objectID)

        // Update
        let foodName = "Food-\(UUID().uuidString)"
        try service.updateCategory(cat, name: foodName, color: "#11AA11")
        #expect(cat.name == foodName)
        #expect(cat.color == "#11AA11")

        // Delete
        try service.deleteCategory(cat)
        let afterDeleteOne = try service.fetchAllCategories()
        // Only our Utilities should remain among the ones we added
        #expect(afterDeleteOne.contains { $0.name == utilitiesName })
        #expect(!afterDeleteOne.contains { $0.name == foodName })

        // Clean up the second we added to restore baseline
        if let util = afterDeleteOne.first(where: { $0.name == utilitiesName }) {
            try service.deleteCategory(util)
        }
        let restored = try service.fetchAllCategories()
        #expect(restored.count == baseline)
    }

    @Test
    func ensure_unique_name_returns_existing() throws {
        let service = try freshService()
        let baseline = try service.fetchAllCategories().count

        // Use a unique base to avoid clashing with any existing "Fuel"
        let base = "fuel-\(UUID().uuidString)"
        let a = try service.addCategory(name: base.capitalized, color: "#FF9900", ensureUniqueName: true)
        let b = try service.addCategory(name: base.uppercased(), color: "#FFFFFF", ensureUniqueName: true)
        #expect(a.objectID == b.objectID)
        #expect(try service.fetchAllCategories().count == baseline + 1)
    }
}
