import SwiftUI
import CoreData

/// Simple sheet to attach/detach cards for a given budget.
struct ManageBudgetCardsSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let budget: Budget
    let onDone: () -> Void

    @FetchRequest private var cards: FetchedResults<Card>

    init(budget: Budget, onDone: @escaping () -> Void) {
        self.budget = budget
        self.onDone = onDone
        let req: NSFetchRequest<Card> = NSFetchRequest(entityName: "Card")
        req.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        _cards = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(cards, id: \.objectID) { card in
                    HStack {
                        Text(card.name ?? "Untitled")
                        Spacer()
                        Toggle("", isOn: binding(for: card))
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Manage Cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss(); onDone() } }
            }
        }
    }

    private func binding(for card: Card) -> Binding<Bool> {
        Binding<Bool>(
            get: { isAttached(card) },
            set: { newValue in
                if newValue { attach(card) } else { detach(card) }
            }
        )
    }

    private func isAttached(_ card: Card) -> Bool {
        let set = card.value(forKey: "budget") as? NSSet
        return set?.contains(budget) ?? false
    }

    private func attach(_ card: Card) {
        let mset = card.mutableSetValue(forKey: "budget")
        if !mset.contains(budget) { mset.add(budget) }
        try? viewContext.save()
    }

    private func detach(_ card: Card) {
        let mset = card.mutableSetValue(forKey: "budget")
        if mset.contains(budget) { mset.remove(budget) }
        try? viewContext.save()
    }
}

