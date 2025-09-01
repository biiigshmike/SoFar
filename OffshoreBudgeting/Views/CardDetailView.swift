//
//  CardDetailView.swift
//  SoFar
//
//  Wallet-style detail for a selected Card.
//  - Top bar: Done + Search, Edit
//  - iOS/macOS safe toolbar & searchable usage
//

import SwiftUI
import CoreData

// MARK: - CardDetailView
struct CardDetailView: View {
    // MARK: Inputs
    let card: CardItem
    let namespace: Namespace.ID
    @Binding var isPresentingAddExpense: Bool
    var onDone: () -> Void
    var onEdit: () -> Void

    // MARK: State
    @StateObject private var viewModel: CardDetailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    private let cardHeight: CGFloat = 170
    private let initialHeaderTopPadding: CGFloat = 16
    
    // MARK: Init
    init(card: CardItem,
         namespace: Namespace.ID,
         isPresentingAddExpense: Binding<Bool>,
         onDone: @escaping () -> Void,
         onEdit: @escaping () -> Void) {
        self.card = card
        self.namespace = namespace
        self._isPresentingAddExpense = isPresentingAddExpense
        self.onDone = onDone
        self.onEdit = onEdit
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
                        if isSearchActive {
                            TextField("Search expenses", text: $viewModel.searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                                .focused($isSearchFieldFocused)
                            Button("Cancel") {
                                withAnimation {
                                    isSearchActive = false
                                    viewModel.searchText = ""
                                    isSearchFieldFocused = false
                                }
                            }
                        } else {
                            IconOnlyButton(systemName: "magnifyingglass") {
                                withAnimation { isSearchActive = true }
                                isSearchFieldFocused = true
                            }
                            IconOnlyButton(systemName: "pencil") {
                                onEdit()
                            }
                        }
                    }
                #else
                    // macOS placements
                    ToolbarItem(placement: .automatic) {
                        Button("Done") { onDone() }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                    ToolbarItemGroup(placement: .automatic) {
                        if isSearchActive {
                            TextField("Search expenses", text: $viewModel.searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .focused($isSearchFieldFocused)
                            Button("Cancel") {
                                withAnimation {
                                    isSearchActive = false
                                    viewModel.searchText = ""
                                    isSearchFieldFocused = false
                                }
                            }
                        } else {
                            IconOnlyButton(systemName: "magnifyingglass") {
                                withAnimation { isSearchActive = true }
                                isSearchFieldFocused = true
                            }
                            IconOnlyButton(systemName: "pencil") {
                                onEdit()
                            }
                        }
                    }
                #endif
                }
        }
        .task { await viewModel.load() }
        //.accentColor(themeManager.selectedTheme.tint)
        //.tint(themeManager.selectedTheme.tint)
        // Add Unplanned Expense sheet for this card
        .sheet(isPresented: $isPresentingAddExpense) {
            AddUnplannedExpenseView(
                initialCardID: card.objectID,
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
        .background(themeManager.selectedTheme.background.ignoresSafeArea())
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
                    .padding(.top, initialHeaderTopPadding)
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
        case .loaded(let total, _, _):
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    Section {
                        totalsSection(total: total)
                        categoryBreakdown(categories: viewModel.filteredCategories)
                        expensesList
                    } header: {
                        GeometryReader { proxy in
                            let offset = min(0, proxy.frame(in: .named("detailScroll")).minY)
                            let scale = max(0.7, 1 + (offset / 300))
                            headerCard
                                .padding(.top, initialHeaderTopPadding)
                                .scaleEffect(scale, anchor: .top)
                                .offset(y: -offset)
                        }
                        .frame(height: cardHeight + initialHeaderTopPadding)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "detailScroll")
    }
    }

    // MARK: Header Card (matched geometry)
    private var headerCard: some View {
        CardTileView(card: card, isSelected: true) {}
            .matchedGeometryEffect(id: "card-\(card.id)", in: namespace, isSource: false)
            .frame(height: cardHeight)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
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
                ForEach(viewModel.filteredExpenses) { expense in
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
    let expense: CardExpense
    private let df: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        return d
    }()
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.body.weight(.medium))
                if let date = expense.date {
                    Text(df.string(from: date)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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
        default: return "Action"
        }
    }
}

