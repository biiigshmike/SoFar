//
//  CardsView.swift
//  SoFar
//
//  Responsive grid of cards with a single, stable data stream.
//  Jitter hardened by:
//   1) Stable identity (objectID-based) on items.
//   2) Disabling implicit animations for list diffs.
//   3) Consistent tile height to prevent adaptive grid reflow.
//
//  Update (selection):
//  - Tracks selected card via stable CardItem.id
//  - Passes isSelected into CardTileView
//  - Tap selects card (ready to show expenses panel next)
//
//  Usage tips:
//  - Keep `CardTileView` in sync with the same “credit card” style used elsewhere
//  - For consistency, this view only owns selection & presentation state.
//

import SwiftUI
import CoreData

// MARK: - CardsView
struct CardsView: View {

    // MARK: State & Dependencies
    @StateObject private var viewModel = CardsViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities
    @State private var isPresentingAddCard = false
    @State private var editingCard: CardItem? = nil // NEW: for edit sheet
    @State private var isPresentingAddExpense = false

    // MARK: Selection State
    /// Stable selection keyed to CardItem.id (works for objectID-backed and preview items).
    @State private var selectedCardStableID: String? = nil

    // MARK: Grid Layout
    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 260, maximum: 260), spacing: DS.Spacing.l)
    ]

    // MARK: Layout Constants
    private let fixedCardHeight: CGFloat = 160

    // MARK: Body
    var body: some View {
        RootTabPageScaffold(scrollBehavior: .always, spacing: DS.Spacing.s) {
            EmptyView()
        } content: { proxy in
            contentView(using: proxy)
        }
        // MARK: Start observing when view appears
        .onAppear { viewModel.startIfNeeded() }
        // Pull to refresh to manually reload cards
        .refreshable { await viewModel.refresh() }
        // MARK: App Toolbar
        .ub_tabNavigationTitle("Cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addActionToolbarButton
            }
        }
        // MARK: Add Sheet
        .sheet(isPresented: $isPresentingAddCard) {
            AddCardFormView { newName, selectedTheme in
                Task { await viewModel.addCard(name: newName, theme: selectedTheme) }
            }
        }
        // MARK: Edit Sheet
        .sheet(item: $editingCard) { card in
            AddCardFormView(mode: .edit, editingCard: card) { newName, selectedTheme in
                Task { await viewModel.edit(card: card, name: newName, theme: selectedTheme) }
            }
        }
        // MARK: Alerts
        .alert(item: $viewModel.alert) { alert in
            switch alert.kind {
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .confirmDelete(let card):
                return Alert(
                    title: Text("Delete “\(card.name)”?"),
                    message: Text("THis will delete the card and all of its expenses."),
                    primaryButton: .destructive(Text("Delete"), action: {
                        Task { await viewModel.confirmDelete(card: card) }
                    }),
                    secondaryButton: .cancel()
                )
            case .rename:
                // No longer exposed in the menu; keeping alert route disabled.
                return Alert(
                    title: Text("Rename Card"),
                    message: Text("Use “Edit…” instead."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        // Keeping this for backwards-compat; not used now that we have “Edit…”.
        .sheet(item: $viewModel.renameTarget) { card in
            RenameCardSheet(
                originalName: card.name,
                onSave: { newName in Task { await viewModel.rename(card: card, to: newName) } }
            )
        }
        .tint(themeManager.selectedTheme.resolvedTint)
    }

    private var addActionToolbarButton: some View {
        Menu {
            Button {
                isPresentingAddCard = true
            } label: {
                Label("Add Card", systemImage: "creditcard")
            }

            Button {
                isPresentingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus.forwardslash.minus")
            }
            .disabled(selectedCardStableID == nil)
        } primaryAction: {
            if selectedCardStableID == nil {
                isPresentingAddCard = true
            } else {
                isPresentingAddExpense = true
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .accessibilityLabel(selectedCardStableID == nil ? "Add Card" : "Add Expense")
        }
    }

    // MARK: - Content View (Type-Safe)
    /// Breaks out the conditional UI so the compiler can infer a single `some View`.
    @ViewBuilder
    private func contentView(using proxy: RootTabPageProxy) -> some View {
        let tabBarGutter = proxy.compactAwareTabBarGutter

        Group {
            if case .initial = viewModel.state {
                Color.clear
            } else if case .loading = viewModel.state {
                loadingView(using: proxy)
            } else if case .empty = viewModel.state {
                emptyView(using: proxy)
            } else if case .loaded(let cards) = viewModel.state {
                gridView(cards: cards, using: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .rootTabContentPadding(
            proxy,
            horizontal: 0,
            tabBarGutter: tabBarGutter
        )
    }

    // MARK: Loading View
    private func loadingView(using proxy: RootTabPageProxy) -> some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.l) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: fixedCardHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.card)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .redacted(reason: .placeholder)
                        .shimmer()
                }
            }
            .padding([.horizontal, .top], DS.Spacing.l)
            .padding(.bottom, proxy.tabBarGutterSpacing(proxy.compactAwareTabBarGutter))
        }
        // Removed extra bottom inset; RootTabPageScaffold + rootTabContentPadding
        // control any desired gutter above the tab bar.
    }

    // MARK: Empty View
    private func emptyView(using proxy: RootTabPageProxy) -> some View {
        UBEmptyState(
            iconSystemName: "creditcard",
            title: "Cards",
            message: "Add the cards you use for spending. We'll use them in budgets later.",
            primaryButtonTitle: "Add Card",
            onPrimaryTap: { isPresentingAddCard = true }
        )
        .padding(.horizontal, DS.Spacing.l)
        .frame(maxWidth: .infinity)
        .frame(minHeight: proxy.availableHeightBelowHeader, alignment: .center)
    }

    // MARK: Grid View
    /// - Parameter cards: Data snapshot to render.
    private func gridView(cards: [CardItem], using proxy: RootTabPageProxy) -> some View {
        ZStack {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.l) {
                ForEach(cards) { card in
                    CardTileView(
                        card: card,
                        isSelected: selectedCardStableID == card.id
                    ) {
                        // MARK: On Tap → Select Card
                        // This highlights the card with a color-matched ring + glow.
                        selectedCardStableID = card.id

                        // TODO: Navigate or reveal expenses for `card`.
                        // e.g., vm.showExpenses(for: card) or set a sidebar selection.
                    }
                    .frame(height: fixedCardHeight)
                    .opacity(selectedCardStableID == nil ? 1 : 0)
                    .animation(.smooth(duration: 0.25), value: selectedCardStableID)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            editingCard = card
                        }
                        Button(role: .destructive) {
                            viewModel.requestDelete(card: card)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding([.horizontal, .top], DS.Spacing.l)
            .padding(.bottom, proxy.tabBarGutterSpacing(proxy.compactAwareTabBarGutter))
            // Disable the default animation for grid changes to prevent "grid hop".
            .animation(nil, value: cards)
        }
        // Removed extra bottom inset; RootTabPageScaffold + rootTabContentPadding
        // control any desired gutter above the tab bar.
            // Detail overlay
            if let selID = selectedCardStableID,
               let selected = cards.first(where: { $0.id == selID }) {
                CardDetailView(
                    card: selected,
                    isPresentingAddExpense: $isPresentingAddExpense,
                    onDone: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                            selectedCardStableID = nil
                            isPresentingAddExpense = false
                        }
                    },
                    onEdit: { editingCard = selected }
                )
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                         removal: .opacity))
                .zIndex(10)
            }
        } // ZStack
        // MARK: Keep selection valid when dataset changes (delete/rename)
        .ub_onChange(of: cards.map(\.id)) { newIDs in
            guard let sel = selectedCardStableID, !newIDs.contains(sel) else { return }

            // Core Data can momentarily emit a data set that omits the
            // selected card when inserting the very first expense. Verify the
            // card still exists before clearing the selection so the detail
            // view remains on screen.
            if let url = URL(string: sel),
               let oid = CoreDataService.shared.container
                .persistentStoreCoordinator
                    .managedObjectID(forURIRepresentation: url),
               (try? CoreDataService.shared.viewContext
                    .existingObject(with: oid)) is Card {
                return
            }

            selectedCardStableID = nil
        }
    }

}

// MARK: - Tiny shimmer for placeholder
private extension View {
    /// Lightweight shimmer to hint loading (iOS/macOS). No external deps.
    /// Implemented with a stable, self-contained animation to avoid
    /// recomposition loops that can stall gesture handling on newer OSes.
    func shimmer() -> some View {
        overlay(ShimmerOverlay().mask(self))
    }
}

private struct ShimmerOverlay: View {
    @State private var animate = false

    private var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(0.0), location: 0.0),
                .init(color: .white.opacity(0.35), location: 0.45),
                .init(color: .white.opacity(0.0), location: 1.0),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Rectangle()
            .fill(gradient)
            .rotationEffect(.degrees(12))
            .blendMode(.overlay)
            .opacity(0.35)
            .offset(x: animate ? 300 : -300)
            .allowsHitTesting(false)
            .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: animate)
            .onAppear { animate = true }
    }
}
