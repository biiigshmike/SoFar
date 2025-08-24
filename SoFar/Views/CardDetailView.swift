//
//  CardDetailView.swift
//  SoFar
//
//  Wallet-style detail for a selected Card.
//  - Top bar: Done + Search, Add, Edit
//  - iOS/macOS safe toolbar & searchable usage
//

import SwiftUI
import CoreData

// MARK: - CardDetailView
struct CardDetailView: View {
    // MARK: Inputs
    let card: CardItem
    let namespace: Namespace.ID
    var onDone: () -> Void
    var onEdit: () -> Void
    @Binding var addExpenseRequest: Bool

    // MARK: State
    @StateObject private var viewModel: CardDetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isSearchActive: Bool = false   // iOS 17+/macOS 14+
    @State private var isPresentingAddExpense: Bool = false
    
    // MARK: Init
    init(card: CardItem,
         namespace: Namespace.ID,
         onDone: @escaping () -> Void,
         onEdit: @escaping () -> Void,
         addExpenseRequest: Binding<Bool>) {
        self.card = card
        self.namespace = namespace
        self.onDone = onDone
        self.onEdit = onEdit
        self._addExpenseRequest = addExpenseRequest
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(card: card))
    }
    
    // MARK: Body
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(card.name)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                #if os(iOS)
                    // iOS placements
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { onDone() }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        IconOnlyButton(systemName: "magnifyingglass") {
                            if #available(iOS 17.0, *) {
                                withAnimation(.smooth(duration: 0.2)) { isSearchActive = true }
                            }
                        }
                        IconOnlyButton(systemName: "pencil") {
                            onEdit()
                        }
                    }
                #else
                    // macOS placements
                    ToolbarItem(placement: .automatic) {
                        Button("Done") { onDone() }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                    ToolbarItemGroup(placement: .automatic) {
                        IconOnlyButton(systemName: "magnifyingglass") {
                            if #available(macOS 14.0, *) {
                                withAnimation(.smooth(duration: 0.2)) { isSearchActive = true }
                            }
                        }
                        IconOnlyButton(systemName: "pencil") {
                            onEdit()
                        }
                    }
                #endif
                }
        }
        .tint(themeManager.selectedTheme.accent)
        .onChange(of: addExpenseRequest) { _, newValue in
            if newValue {
                isPresentingAddExpense = true
                addExpenseRequest = false
            }
        }
        // Search field wiring per-platform
        #if os(iOS)
        .modifier(SearchableModifier_iOS(text: $viewModel.searchText, isActive: $isSearchActive))
        #else
        .modifier(SearchableModifier_mac(text: $viewModel.searchText, isActive: $isSearchActive))
        #endif
        .task { await viewModel.load() }
        // Add Unplanned Expense sheet for this card
        .sheet(isPresented: $isPresentingAddExpense) {
            let allowedIDs: Set<NSManagedObjectID>? = {
                if let oid = card.objectID { return [oid] }
                return nil
            }()
            AddUnplannedExpenseView(
                allowedCardIDs: allowedIDs,
                initialDate: Date(),
                onSaved: {
                    isPresentingAddExpense = false
                    Task { await viewModel.load() }
                }
            )
            #if os(macOS)
            .presentationSizing(.fitted)   // <- ensures the sheet respects the view’s ideal size
            #endif
        }

    }
    
    // MARK: content
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .initial, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .bold))
                Text("Couldn’t load details")
                    .font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        case .empty:
            VStack(spacing: 16) {
                headerCard
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No expenses yet")
                        .font(.title3.weight(.semibold))
                    Text("Add an expense to see totals and categories here.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // <- center vertically
            }
            .padding()
        case .loaded(let total, let categories, _):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    totalsSection(total: total)
                    categoryBreakdown(categories: categories)
                    expensesList
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: Header Card (matched geometry)
    private var headerCard: some View {
        CardTileView(card: card, isSelected: true) {}
            .matchedGeometryEffect(id: "card-\(card.id)", in: namespace)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity, alignment: .center)   // <- center horizontally
                    .padding(.top)
    }
    
    // MARK: totalsSection
    private func totalsSection(total: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOTAL SPENT")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.selectedTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: categoryBreakdown
    private func categoryBreakdown(categories: [CardCategoryTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY CATEGORY")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(categories) { cat in
                HStack {
                    Circle()
                        .fill(cat.color)
                        .frame(width: 10, height: 10)
                    Text(cat.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(cat.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .monospacedDigit()
                        .font(.callout.weight(.semibold))
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.selectedTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: expensesList
    private var expensesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPENSES")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if viewModel.filteredExpenses.isEmpty {
                Text(viewModel.searchText.isEmpty ? "No expenses found." : "No results for “\(viewModel.searchText)”")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.filteredExpenses, id: \.objectID) { expense in
                    ExpenseRow(expense: expense)
                    Divider().opacity(0.15)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.selectedTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ExpenseRow
private struct ExpenseRow: View {
    let expense: UnplannedExpense
    private let df: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        return d
    }()
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.value(forKey: "descriptionText") as? String ?? "Untitled")
                    .font(.body.weight(.medium))
                if let date = expense.value(forKey: "transactionDate") as? Date {
                    Text(df.string(from: date)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text((expense.value(forKey: "amount") as? Double) ?? 0, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.body.weight(.semibold)).monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared Toolbar Icon
private struct IconOnlyButton: View {
    let systemName: String
    var action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(themeManager.selectedTheme.accent)
                .imageScale(.medium)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
    private var label: String {
        switch systemName {
        case "magnifyingglass": return "Search"
        case "pencil": return "Edit"
        case "plus": return "Add Expense"
        default: return "Action"
        }
    }
}

#if os(iOS)
// MARK: - Searchable (iOS)
private struct SearchableModifier_iOS: ViewModifier {
    @Binding var text: String
    @Binding var isActive: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.searchable(text: $text,
                               isPresented: $isActive,
                               placement: .navigationBarDrawer(displayMode: .always),
                               prompt: Text("Search expenses"))
        } else {
            content.searchable(text: $text,
                               placement: .navigationBarDrawer(displayMode: .always),
                               prompt: Text("Search expenses"))
        }
    }
}
#else
// MARK: - Searchable (macOS)
private struct SearchableModifier_mac: ViewModifier {
    @Binding var text: String
    @Binding var isActive: Bool
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.searchable(text: $text,
                               isPresented: $isActive,
                               prompt: Text("Search expenses"))
        } else {
            content.searchable(text: $text, prompt: Text("Search expenses"))
        }
    }
}
#endif
