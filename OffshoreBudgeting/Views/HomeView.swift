//
//  HomeView.swift
//  SoFar
//
//  Displays month header and, when a budget exists for the selected month,
//  shows the full BudgetDetailsView inline. Otherwise an empty state encourages
//  creating a budget.
//
//  Empty-state centering:
//  - We place a ZStack as the content container *below the header*.
//  - When there are no budgets, we show UBEmptyState inside that ZStack.
//  - UBEmptyState uses maxWidth/maxHeight = .infinity, so it centers itself
//    within the ZStack's available area (i.e., the viewport minus the header).
//  - When budgets exist, we show BudgetDetailsView in the same ZStack,
//    so there’s no layout jump switching between states.
//

import SwiftUI
import CoreData
import Foundation
import Combine

// MARK: - HomeView
struct HomeView: View {

    // MARK: State & ViewModel
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage(AppSettingsKeys.budgetPeriod.rawValue) private var budgetPeriodRawValue: String = BudgetPeriod.monthly.rawValue
    private var budgetPeriod: BudgetPeriod { BudgetPeriod(rawValue: budgetPeriodRawValue) ?? .monthly }

    // MARK: Add Budget Sheet
    @State private var isPresentingAddBudget: Bool = false
    @State private var editingBudget: BudgetSummary?

    // MARK: Body
    var body: some View {
        mainLayout
        // Make the whole screen participate so the ZStack gets the full height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ub_tabNavigationTitle("Home")
        .refreshable { await vm.refresh() }
        .task {
            CoreDataService.shared.ensureLoaded()
            vm.startIfNeeded()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .dataStoreDidChange)
                .receive(on: RunLoop.main)
        ) { _ in
            Task { await vm.refresh() }
        }
        .ub_onChange(of: budgetPeriodRawValue) { newValue in
            let newPeriod = BudgetPeriod(rawValue: newValue) ?? .monthly
            vm.updateBudgetPeriod(to: newPeriod)
        }

        // MARK: ADD SHEET — present new budget UI for the selected period
        .sheet(isPresented: $isPresentingAddBudget, content: makeAddBudgetView)
        .sheet(item: $editingBudget, content: makeEditBudgetView)
        .alert(item: $vm.alert, content: alert(for:))
        .ub_surfaceBackground(
            themeManager.selectedTheme,
            configuration: themeManager.glassConfiguration,
            ignoringSafeArea: .all
        )
    }

    // MARK: Root Layout
    private var mainLayout: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            headerSection

            // MARK: Content Container
            // ZStack gives us a stable area below the header.
            // - When empty: we show UBEmptyState centered here.
            // - When non-empty: we show the budget details here.
            contentContainer
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            RootViewTopPlanes(
                title: "Home",
                topPaddingStyle: .navigationBarAligned
            ) {
                headerActions
            }

            header
                .padding(.horizontal, RootTabHeaderLayout.defaultHorizontalPadding)
        }
    }

    private var headerActions: some View {
#if os(macOS)
        HStack(spacing: DS.Spacing.s) {
            periodPickerControl
            if let trailing = trailingActionControl {
                trailing
            }
        }
#else
        if let trailing = trailingActionControl {
            RootHeaderGlassPill {
                periodPickerControl
            } trailing: {
                trailing
            }
        } else {
            RootHeaderGlassControl {
                periodPickerControl
            }
        }
#endif
    }

    @ViewBuilder
    private var periodPickerControl: some View {
        Menu {
            ForEach(BudgetPeriod.selectableCases) { period in
                Button(period.displayName) { budgetPeriodRawValue = period.rawValue }
            }
        } label: {
#if os(macOS)
            Label(budgetPeriod.displayName, systemImage: "calendar")
#else
            RootHeaderControlIcon(systemImage: "calendar")
                .accessibilityLabel(budgetPeriod.displayName)
#endif
        }
#if os(iOS)
        .modifier(HideMenuIndicatorIfPossible())
#endif
    }

    private var trailingActionControl: AnyView? {
        switch vm.state {
        case .empty:
            return AnyView(addBudgetButton)
        case .loaded(let summaries):
            if let first = summaries.first {
                return AnyView(budgetActionMenu(for: first))
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    private var addBudgetButton: some View {
        Button {
            isPresentingAddBudget = true
        } label: {
            RootHeaderControlIcon(systemImage: "plus")
        }
#if os(iOS)
        .buttonStyle(RootHeaderActionButtonStyle())
#else
        .buttonStyle(.plain)
#endif
        .accessibilityLabel("Add Budget")
    }

    private func budgetActionMenu(for summary: BudgetSummary) -> some View {
        Menu {
            Button {
                editingBudget = summary
            } label: {
                Label("Edit Budget", systemImage: "pencil")
            }
            Button(role: .destructive) {
                vm.requestDelete(budgetID: summary.id)
            } label: {
                Label("Delete Budget", systemImage: "trash")
            }
        } label: {
            RootHeaderControlIcon(systemImage: "ellipsis")
                .accessibilityLabel("Budget Actions")
        }
#if os(iOS)
        .modifier(HideMenuIndicatorIfPossible())
#endif
    }

    fileprivate enum ToolbarButtonMetrics {
        static let dimension: CGFloat = 44
    }

    // MARK: Sheets & Alerts
    @ViewBuilder
    private func makeAddBudgetView() -> some View {
        let (start, end) = budgetPeriod.range(containing: vm.selectedDate)
        if #available(iOS 16.0, *) {
            AddBudgetView(
                initialStartDate: start,
                initialEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
        } else {
            AddBudgetView(
                initialStartDate: start,
                initialEndDate: end,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    @ViewBuilder
    private func makeEditBudgetView(summary: BudgetSummary) -> some View {
        if #available(iOS 16.0, *) {
            AddBudgetView(
                editingBudgetObjectID: summary.id,
                fallbackStartDate: summary.periodStart,
                fallbackEndDate: summary.periodEnd,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
            .presentationDetents([.large, .medium])
        } else {
            AddBudgetView(
                editingBudgetObjectID: summary.id,
                fallbackStartDate: summary.periodStart,
                fallbackEndDate: summary.periodEnd,
                onSaved: { Task { await vm.refresh() } }
            )
            .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }

    private func alert(for alert: HomeViewAlert) -> Alert {
        switch alert.kind {
        case .error(let message):
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        case .confirmDelete(let id):
            return Alert(
                title: Text("Delete Budget?"),
                message: Text("This action cannot be undone."),
                primaryButton: .destructive(Text("Delete"), action: { Task { await vm.confirmDelete(budgetID: id) } }),
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: Content Container
    private var contentContainer: some View {
        ZStack {
            switch vm.state {
            case .initial:
                // Initially nothing is shown to prevent blinking
                Color.clear
                
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .empty:
                // Show empty state only when we've confirmed there are no budgets
                UBEmptyState(
                    iconSystemName: "rectangle.on.rectangle.slash",
                    title: "Budgets",
                    message: "No budget found for \(title(for: vm.selectedDate)). Tap + to create a new budget for this period.",
                    primaryButtonTitle: "Create a budget",
                    onPrimaryTap: { isPresentingAddBudget = true }
                )
                .padding(.horizontal, DS.Spacing.l)
                .accessibilityElement(children: .contain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
            case .loaded(let summaries):
                if let first = summaries.first {
                    BudgetDetailsView(budgetObjectID: first.id)
                        .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                        .id(first.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    UBEmptyState(
                        iconSystemName: "rectangle.on.rectangle.slash",
                        title: "Budgets",
                        message: "No budget found for \(title(for: vm.selectedDate)). Tap + to create a new budget for this period.",
                        primaryButtonTitle: "Create a budget",
                        onPrimaryTap: { isPresentingAddBudget = true }
                    )
                    .padding(.horizontal, DS.Spacing.l)
                    .accessibilityElement(children: .contain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        // Fill remaining viewport under header so centering is exact.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: DS.Spacing.s) {
            Button { vm.adjustSelectedPeriod(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Text(title(for: vm.selectedDate))
                .font(.title2).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Button { vm.adjustSelectedPeriod(by: +1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers
    private func title(for date: Date) -> String {
        budgetPeriod.title(for: date)
    }
}

// MARK: - Header Action Helpers
#if os(iOS)
private struct RootHeaderGlassPill<Leading: View, Trailing: View>: View {
    private enum Metrics {
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 6
        static let dividerInset: CGFloat = 4
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        let dimension = HomeView.ToolbarButtonMetrics.dimension
        let dividerHeight = dimension - (Metrics.dividerInset * 2)
        let theme = themeManager.selectedTheme

        let content = HStack(spacing: 0) {
            leading
                .frame(width: dimension, height: dimension)
                .contentShape(Rectangle())

            Rectangle()
                .fill(RootHeaderLegacyGlass.dividerColor(for: theme))
                .frame(width: 1, height: dividerHeight)
                .padding(.vertical, Metrics.dividerInset)

            trailing
                .frame(width: dimension, height: dimension)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .contentShape(Capsule(style: .continuous))

        if #available(iOS 18.0, *), capabilities.supportsOS26Translucency {
            GlassEffectContainer {
                content
                    .glassEffect(in: Capsule(style: .continuous))
            }
        } else {
            content
                .rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
        }
    }
}

private struct RootHeaderGlassControl<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.platformCapabilities) private var capabilities

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let dimension = HomeView.ToolbarButtonMetrics.dimension
        let theme = themeManager.selectedTheme

        let control = content
            .frame(width: dimension, height: dimension)
            .contentShape(Rectangle())
            .padding(.horizontal, RootHeaderGlassMetrics.horizontalPadding)
            .padding(.vertical, RootHeaderGlassMetrics.verticalPadding)
            .contentShape(Capsule(style: .continuous))

        if #available(iOS 18.0, *), capabilities.supportsOS26Translucency {
            GlassEffectContainer {
                control
                    .glassEffect(in: Capsule(style: .continuous))
            }
        } else {
            control
                .rootHeaderLegacyGlassDecorated(theme: theme, capabilities: capabilities)
        }
    }
}

private enum RootHeaderGlassMetrics {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 6
}

private enum RootHeaderLegacyGlass {
    static func fillColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.30) : theme.resolvedTint.opacity(0.32)
    }

    static func shadowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.black.opacity(0.28) : theme.resolvedTint.opacity(0.42)
    }

    static func borderColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.50) : theme.resolvedTint.opacity(0.58)
    }

    static func dividerColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white.opacity(0.32) : theme.resolvedTint.opacity(0.40)
    }

    static func glowColor(for theme: AppTheme) -> Color {
        theme == .system ? Color.white : theme.resolvedTint
    }

    static func glowOpacity(for theme: AppTheme) -> Double {
        theme == .system ? 0.32 : 0.42
    }

    static func borderLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 1.15 : 1.0
    }

    static func highlightLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 0.9 : 0.8
    }

    static func highlightOpacity(for capabilities: PlatformCapabilities) -> Double {
        capabilities.supportsOS26Translucency ? 0.24 : 0.18
    }

    static func glowLineWidth(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 12 : 9
    }

    static func glowBlurRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowRadius(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 16 : 12
    }

    static func shadowYOffset(for capabilities: PlatformCapabilities) -> CGFloat {
        capabilities.supportsOS26Translucency ? 10 : 9
    }
}

private extension View {
    func rootHeaderLegacyGlassDecorated(theme: AppTheme, capabilities: PlatformCapabilities) -> some View {
        let shape = Capsule(style: .continuous)
        return self
            .background(
                shape
                    .fill(RootHeaderLegacyGlass.fillColor(for: theme))
                    .shadow(
                        color: RootHeaderLegacyGlass.shadowColor(for: theme),
                        radius: RootHeaderLegacyGlass.shadowRadius(for: capabilities),
                        x: 0,
                        y: RootHeaderLegacyGlass.shadowYOffset(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.borderColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.borderLineWidth(for: capabilities)
                    )
            )
            .overlay(
                shape
                    .stroke(
                        Color.white.opacity(RootHeaderLegacyGlass.highlightOpacity(for: capabilities)),
                        lineWidth: RootHeaderLegacyGlass.highlightLineWidth(for: capabilities)
                    )
                    .blendMode(.screen)
            )
            .overlay(
                shape
                    .stroke(
                        RootHeaderLegacyGlass.glowColor(for: theme),
                        lineWidth: RootHeaderLegacyGlass.glowLineWidth(for: capabilities)
                    )
                    .blur(radius: RootHeaderLegacyGlass.glowBlurRadius(for: capabilities))
                    .opacity(RootHeaderLegacyGlass.glowOpacity(for: theme))
                    .blendMode(.screen)
            )
            .compositingGroup()
    }
}
#endif

private struct RootHeaderControlIcon: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(foregroundColor)
    }

    private var foregroundColor: Color {
        themeManager.selectedTheme == .system ? Color.primary : Color.white
    }
}

private struct RootHeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

#if os(iOS)
private struct HideMenuIndicatorIfPossible: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.menuIndicator(.hidden)
        } else {
            content
        }
    }
}
#endif

