# AGENTS.md

This document guides code agents on how to safely read, plan, and modify this repository. It is optimized for step-based tools that generate full-file patches. Keep changes scoped, reversible, and consistent with existing patterns.

## Repository overview

```
./
Offshore/
  .DS_Store
  ContentView.swift
  Info.plist
  OffshoreBudgeting.entitlements
  OffshoreBudgetingApp.swift
  OffshoreBudgeting/View Models/
    AddBudgetViewModel.swift
    AddIncomeFormViewModel.swift
    AddPlannedExpenseViewModel.swift
    AddUnplannedExpenseViewModel.swift
    BudgetDetailsViewModel.swift
    BudgetDetailsViewModelStore.swift
    CardDetailViewModel.swift
    CardsViewModel.swift
    HomeViewModel.swift
    IncomeScreenViewModel.swift
    SettingsViewModel.swift
  OffshoreBudgeting/Resources/
    AddIncomeFormView+Lifecycle.swift
    BudgetIncomeCalculator.swift
    CardItem+CoreDataBridge.swift
    Color+Hex.swift
    CoreDataEntityChangeMonitor.swift
    CoreDataListObserver.swift
    HolographicMetallicText.swift
    NotificationName+Extensions.swift
    PlannedExpenseService+Templates.swift
    RecurrenceRule.swift
    SaveError.swift
    UnifiedSwipeActions.swift
  OffshoreBudgeting/Assets.xcassets/
    .DS_Store
    Contents.json
  OffshoreBudgeting/Models/
    BudgetPeriod.swift
    CardItem.swift
  OffshoreBudgeting/AppIcon.icon/
    icon.json
    OffshoreBudgeting/AppIcon.icon/Assets/
      Offshore Budgeting Icon Design.png
  OffshoreBudgeting/Testing/
    UITestDataSeeder.swift
  OffshoreBudgeting/Support/
    Logging.swift
  OffshoreBudgeting/OffshoreBudgetingModel.xcdatamodeld/
    OffshoreBudgeting/OffshoreBudgetingModel.xcdatamodeld/OffshoreBudgetingModel.xcdatamodel/
      contents
  OffshoreBudgeting/Systems/
    AppSettings.swift
    AppTheme.swift
    CardAppearanceStore.swift
    CardTheme.swift
    Compatibility.swift
    DesignSystem+Motion.swift
    DesignSystem.swift
    MetallicTextStyles.swift
    IncomeCalendarPalette.swift
    MotionSupport.swift
    OnboardingEnvironment.swift
    PlatformCapabilities.swift
    ResponsiveLayoutContext.swift
    RootTabView.swift
    SafeAreaInsetsCompatibility.swift
    ScrollViewInsetAdjustment.swift
    SystemTheme.swift
  OffshoreBudgeting/Views/
    AddBudgetView.swift
    AddCardFormView.swift
    AddIncomeFormView.swift
    AddPlannedExpenseView.swift
    AddUnplannedExpenseView.swift
    BudgetDetailsView.swift
    CardDetailView.swift
    CardPickerItemTile.swift
    CardPickerRow.swift
    CardTileView.swift
    CardsView.swift
    CustomRecurrenceEditorView.swift
    EditSheetScaffold.swift
    ExpenseCategoryManagerView.swift
    HelpView.swift
    HomeView.swift
    IncomeEditorView.swift
    IncomeView.swift
    ManageBudgetCardsSheet.swift
    NoCardTile.swift
    OnboardingView.swift
    PresetBudgetAssignmentSheet.swift
    PresetRowView.swift
    PresetsView.swift
    RecurrencePickerView.swift
    RenameCardSheet.swift
    SettingsView.swift
    UBEmptyState.swift
    UBFormRow.swift
    UBFormSection.swift
    OffshoreBudgeting/Views/Components/
      CalendarNavigationButtonStyle.swift
      PeriodNavigationControl.swift
      RootHeaderActions.swift
      RootTabHeader.swift
      RootTabPageScaffold.swift
      RootViewTopPlanes.swift
      TranslucentButtonStyle.swift
  OffshoreBudgeting/Services/
    BudgetService.swift
    CardService.swift
    CloudAccountStatusProvider.swift
    CoreDataService.swift
    ExpenseCategoryService.swift
    IncomeService.swift
    PlannedExpenseService.swift
    RecurrenceEngine.swift
    UnplannedExpenseService.swift
    OffshoreBudgeting/Services/Repository/
      CoreDataRepository.swift
__MACOSX/
  __MACOSX/OffshoreBudgeting/
    ._.DS_Store
    ._AppIcon.icon
    ._ContentView.swift
    ._Info.plist
    ._OffshoreBudgetingApp.swift
    ._Testing
    __MACOSX/OffshoreBudgeting/View Models/
      ._AddBudgetViewModel.swift
      ._AddIncomeFormViewModel.swift
      ._AddPlannedExpenseViewModel.swift
      ._AddUnplannedExpenseViewModel.swift
      ._BudgetDetailsViewModel.swift
      ._CardDetailViewModel.swift
      ._CardsViewModel.swift
      ._HomeViewModel.swift
      ._IncomeScreenViewModel.swift
      ._SettingsViewModel.swift
    __MACOSX/OffshoreBudgeting/Resources/
      ._AddIncomeFormView+Lifecycle.swift
      ._BudgetIncomeCalculator.swift
      ._CardItem+CoreDataBridge.swift
      ._Color+Hex.swift
      ._CoreDataEntityChangeMonitor.swift
      ._CoreDataListObserver.swift
      ._HolographicMetallicText.swift
      ._NotificationName+Extensions.swift
      ._PlannedExpenseService+Templates.swift
      ._RecurrenceRule.swift
      ._SaveError.swift
      ._UnifiedSwipeActions.swift
    __MACOSX/OffshoreBudgeting/Assets.xcassets/
      ._.DS_Store
    __MACOSX/OffshoreBudgeting/Models/
      ._BudgetPeriod.swift
      ._CardItem.swift
    __MACOSX/OffshoreBudgeting/AppIcon.icon/
      ._Assets
      ._icon.json
      __MACOSX/OffshoreBudgeting/AppIcon.icon/Assets/
        ._Offshore Budgeting Icon Design.png
    __MACOSX/OffshoreBudgeting/Testing/
      ._UITestDataSeeder.swift
    __MACOSX/OffshoreBudgeting/OffshoreBudgetingModel.xcdatamodeld/
      ._OffshoreBudgetingModel.xcdatamodel
      __MACOSX/OffshoreBudgeting/OffshoreBudgetingModel.xcdatamodeld/OffshoreBudgetingModel.xcdatamodel/
        ._contents
    __MACOSX/OffshoreBudgeting/Systems/
      ._AppSettings.swift
      ._AppTheme.swift
      ._CardAppearanceStore.swift
      ._CardTheme.swift
      ._Compatibility.swift
      ._DesignSystem+Motion.swift
      ._DesignSystem.swift
      ._MetallicTextStyles.swift
      ._IncomeCalendarPalette.swift
      ._MotionSupport.swift
      ._OnboardingEnvironment.swift
      ._PlatformCapabilities.swift
      ._ResponsiveLayoutContext.swift
      ._RootTabView.swift
      ._SafeAreaInsetsCompatibility.swift
      ._SystemTheme.swift
    __MACOSX/OffshoreBudgeting/Views/
      ._AddBudgetView.swift
      ._AddCardFormView.swift
      ._AddIncomeFormView.swift
      ._AddPlannedExpenseView.swift
      ._AddUnplannedExpenseView.swift
      ._BudgetDetailsView.swift
      ._CardDetailView.swift
      ._CardPickerItemTile.swift
      ._CardPickerRow.swift
      ._CardTileView.swift
      ._CardsView.swift
      ._Components
      ._CustomRecurrenceEditorView.swift
      ._EditSheetScaffold.swift
      ._ExpenseCategoryManagerView.swift
      ._HelpView.swift
      ._HomeView.swift
      ._IncomeEditorView.swift
      ._IncomeView.swift
      ._NoCardTile.swift
      ._OnboardingView.swift
      ._PresetBudgetAssignmentSheet.swift
      ._PresetRowView.swift
      ._PresetsView.swift
      ._RecurrencePickerView.swift
      ._RenameCardSheet.swift
      ._SettingsView.swift
      ._UBEmptyState.swift
      ._UBFormRow.swift
      ._UBFormSection.swift
      __MACOSX/OffshoreBudgeting/Views/Components/
        ._CalendarNavigationButtonStyle.swift
        ._PeriodNavigationControl.swift
        ._RootHeaderActions.swift
        ._RootTabHeader.swift
        ._RootTabPageScaffold.swift
        ._RootViewTopPlanes.swift
        ._TranslucentButtonStyle.swift
    __MACOSX/OffshoreBudgeting/Services/
      ._BudgetService.swift
      ._CardService.swift
      ._CloudAccountStatusProvider.swift
      ._CoreDataService.swift
      ._ExpenseCategoryService.swift
      ._IncomeService.swift
      ._PlannedExpenseService.swift
      ._RecurrenceEngine.swift
      ._UnplannedExpenseService.swift
      __MACOSX/OffshoreBudgeting/Services/Repository/
        ._CoreDataRepository.swift
```

## Important files by role

### Views (SwiftUI / UI)
- OffshoreBudgeting/ContentView.swift — types: ContentView
- OffshoreBudgeting/Systems/RootTabView.swift — types: RootTabView, Tab, MacToolbarBackgroundModifier, MacRootTabBar, MacTabLabel
- OffshoreBudgeting/Views/PresetsView.swift — types: PresetsView, AddGlobalPlannedExpenseSheet, PresetListItem, PresetsViewModel, Outline
- OffshoreBudgeting/Views/CustomRecurrenceEditorView.swift — types: CustomRecurrence, Unit, CustomRecurrenceEditorView, WeekdayMultiPicker
- OffshoreBudgeting/Views/SettingsView.swift — types: SettingsView
- OffshoreBudgeting/Views/PresetRowView.swift — types: PresetRowView, LabeledAmountBlock
- OffshoreBudgeting/Views/ExpenseCategoryManagerView.swift — types: ExpenseCategoryManagerView, ExpenseCategoryEditorSheet, ColorCircle
- OffshoreBudgeting/Views/HomeView.swift — types: HomeView, HomeHeaderPrimarySummaryView, HomeHeaderPrimarySummaryStyle, HomeHeaderFallbackTitleView, HomeIncomeSavingsZeroSummaryView
- OffshoreBudgeting/Views/AddBudgetView.swift — types: AddBudgetView
- OffshoreBudgeting/Views/CardTileView.swift — types: CardTileView
- OffshoreBudgeting/Views/AddPlannedExpenseView.swift — types: AddPlannedExpenseView, CategoryChipsRow, PresentationDetentsCompat, AddCategoryPill, CategoryChip
- OffshoreBudgeting/Views/IncomeEditorView.swift — types: IncomeEditorMode, IncomeEditorAction, IncomeEditorForm, RecurrenceOption, IncomeEditorView
- OffshoreBudgeting/Views/RecurrencePickerView.swift — types: RecurrencePickerView, Preset, WeekdayPicker, DayOfMonthPicker
- OffshoreBudgeting/Views/AddCardFormView.swift — types: AddCardFormView, Mode, ThemeSwatch
- OffshoreBudgeting/Views/HelpView.swift — types: HelpView, HelpPage, HelpView_Previews
- OffshoreBudgeting/Views/IncomeView.swift — types: AddIncomeSheetDate, IncomeView, CalendarSectionMetrics, IncomeCardHeights, IncomeRow
- OffshoreBudgeting/Views/AddUnplannedExpenseView.swift — types: AddUnplannedExpenseView, CategoryChipsRow, AddCategoryPill, CategoryChip
- OffshoreBudgeting/Views/BudgetDetailsView.swift — types: BudgetDetailsView, PeriodNavigationConfiguration, CombinedBudgetHeaderGrid, SummarySection, BudgetIncomeSavingsSummaryView
- OffshoreBudgeting/Views/CardsView.swift — types: CardsView, ShimmerOverlay
- OffshoreBudgeting/Views/OnboardingView.swift — types: OnboardingView, Step, WelcomeStep, ThemeStep, ThemePreviewTile

### Services / Data access
- OffshoreBudgeting/Resources/PlannedExpenseService+Templates.swift — types: here
- OffshoreBudgeting/Services/CoreDataService.swift — types: CoreDataService, PersistentStoreMode
- OffshoreBudgeting/Services/CardService.swift — types: CardService
- OffshoreBudgeting/Services/BudgetService.swift — types: BudgetService
- OffshoreBudgeting/Services/ExpenseCategoryService.swift — types: ExpenseCategoryService
- OffshoreBudgeting/Services/RecurrenceEngine.swift — types: RecurrenceEngine
- OffshoreBudgeting/Services/CloudAccountStatusProvider.swift — types: CloudAccountStatusProvider, Availability
- OffshoreBudgeting/Services/PlannedExpenseService.swift — types: PlannedExpenseServiceError, PlannedExpenseService
- OffshoreBudgeting/Services/IncomeService.swift — types: RecurrenceScope, IncomeService, IncomeEvent
- OffshoreBudgeting/Services/UnplannedExpenseService.swift — types: UnplannedExpenseService, UnplannedEvent, SplitPart
- OffshoreBudgeting/Services/Repository/CoreDataRepository.swift — types: CoreDataRepository
- __MACOSX/OffshoreBudgeting/Resources/._PlannedExpenseService+Templates.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._CoreDataService.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._CardService.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._BudgetService.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._ExpenseCategoryService.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._RecurrenceEngine.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._CloudAccountStatusProvider.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._PlannedExpenseService.swift — types: N/A
- __MACOSX/OffshoreBudgeting/Services/._IncomeService.swift — types: N/A

### Models / Entities
- OffshoreBudgeting/View Models/AddIncomeFormViewModel.swift — types: AddIncomeFormViewModel, ValidationError
- OffshoreBudgeting/View Models/CardsViewModel.swift — types: CardsLoadState, CardsViewAlert, Kind, CardsViewModel
- OffshoreBudgeting/View Models/HomeViewModel.swift — types: BudgetLoadState, HomeViewAlert, Kind, BudgetSummary, CategorySpending
- OffshoreBudgeting/View Models/CardDetailViewModel.swift — types: CardCategoryTotal, CardExpense, CardDetailLoadState, CardDetailViewModel
- OffshoreBudgeting/View Models/AddPlannedExpenseViewModel.swift — types: AddPlannedExpenseViewModel
- OffshoreBudgeting/View Models/SettingsViewModel.swift — types: SettingsViewModel, SettingsIcon, SettingsCard, SettingsRow
- OffshoreBudgeting/View Models/AddUnplannedExpenseViewModel.swift — types: AddUnplannedExpenseViewModel
- OffshoreBudgeting/View Models/BudgetDetailsViewModelStore.swift — types: BudgetDetailsViewModelStore
- OffshoreBudgeting/View Models/AddBudgetViewModel.swift — types: AddBudgetViewModel
- OffshoreBudgeting/View Models/BudgetDetailsViewModel.swift — types: BudgetDetailsViewModel, Segment, SortOption, BudgetDetailsAlert, Kind
- OffshoreBudgeting/View Models/IncomeScreenViewModel.swift — types: IncomeScreenViewModel
- OffshoreBudgeting/Models/CardItem.swift — types: CardItem
- OffshoreBudgeting/Models/BudgetPeriod.swift — types: BudgetPeriod
- OffshoreBudgeting/Views/PresetsView.swift — types: PresetsView, AddGlobalPlannedExpenseSheet, PresetListItem, PresetsViewModel, Outline
- __MACOSX/OffshoreBudgeting/View Models/._AddIncomeFormViewModel.swift — types: N/A
- __MACOSX/OffshoreBudgeting/View Models/._CardsViewModel.swift — types: N/A
- __MACOSX/OffshoreBudgeting/View Models/._HomeViewModel.swift — types: N/A
- __MACOSX/OffshoreBudgeting/View Models/._CardDetailViewModel.swift — types: N/A
- __MACOSX/OffshoreBudgeting/View Models/._AddPlannedExpenseViewModel.swift — types: N/A
- __MACOSX/OffshoreBudgeting/View Models/._SettingsViewModel.swift — types: N/A

### Systems / Environment / Helpers
- OffshoreBudgeting/Systems/MetallicTextStyles.swift — types: UBTypography, UBDecor
- OffshoreBudgeting/Systems/AppSettings.swift — types: AppSettingsKeys
- OffshoreBudgeting/Systems/ScrollViewInsetAdjustment.swift — types: UBScrollViewInsetAdjustmentDisabler
- OffshoreBudgeting/Systems/PlatformCapabilities.swift — types: PlatformCapabilities, PlatformCapabilitiesKey
- OffshoreBudgeting/Systems/Compatibility.swift — types: UBListStyleLiquidAwareModifier, UBListStyleSeparators, UBPreOS26ListRowBackgroundModifier, UBRootTabNavigationTitleModifier, UBOnChangeWithoutValueModifier
- OffshoreBudgeting/Systems/IncomeCalendarPalette.swift — types: UBMonthLabel, UBDayView, UBWeekdayLabel, UBWeekdaysView
- OffshoreBudgeting/Systems/DesignSystem+Motion.swift — types: Motion
- OffshoreBudgeting/Systems/DesignSystem.swift — types: DesignSystem, Spacing, Radius
- OffshoreBudgeting/Systems/SafeAreaInsetsCompatibility.swift — types: UBSafeAreaInsetsEnvironmentKey, UBSafeAreaInsetsPreferenceKey, UBSafeAreaInsetsReader
- OffshoreBudgeting/Systems/MotionSupport.swift — types: MotionMonitor
- OffshoreBudgeting/Systems/CardTheme.swift — types: CardTheme, BackgroundPattern, DiagonalStripesOverlay, CrossHatchOverlay, GridOverlay
- OffshoreBudgeting/Systems/ResponsiveLayoutContext.swift — types: ResponsiveLayoutContext, Idiom, ResponsiveLayoutContextKey, ResponsiveLayoutReader, LegacySafeAreaCapture
- OffshoreBudgeting/Systems/AppTheme.swift — types: NotificationCenterAdapter, CloudSyncPreferences, AppTheme, TabBarPalette, GlassConfiguration
- OffshoreBudgeting/Systems/OnboardingEnvironment.swift — types: OnboardingPresentationKey
- OffshoreBudgeting/Systems/CardAppearanceStore.swift — types: CardAppearanceStore
- OffshoreBudgeting/Systems/SystemTheme.swift — types: SystemThemeAdapter, Flavor
- OffshoreBudgeting/Systems/RootTabView.swift — types: RootTabView, Tab, MacToolbarBackgroundModifier, MacRootTabBar, MacTabLabel
  (Removed: DesignSystem+Typography.swift, DesignSystem+Decor.swift, HomeHeaderLayoutEnvironment.swift)

## Conventions and constraints

- Preserve naming, structure, and // MARK organization already in the code.
- Prefer small, isolated changes. Avoid refactors unless explicitly requested.
- Keep platform behavior consistent across iOS, iPadOS, and macOS Catalyst when editing UI.
- Avoid adding dependencies without prior approval.

## How to read the code using // MARK and comments

Use the following // MARK anchors to understand intent and safe insertion points. Only add new // MARK sections if needed for clarity.

**OffshoreBudgeting/OffshoreBudgetingApp.swift**
- // MARK: Dependencies
- // MARK: Onboarding State
- // MARK: Init

**OffshoreBudgeting/View Models/AddIncomeFormViewModel.swift**
- // MARK: - AddIncomeFormViewModel
- // MARK: Inputs / Identity
- // MARK: Editing State
- // MARK: Core Fields
- // MARK: Recurrence
- // MARK: Currency
- // MARK: Validation
- // MARK: Init
- // MARK: Load
- // MARK: Save
- // MARK: Parsing & Formatting
- // MARK: Errors
- // MARK: - Safe KVC helpers for schema drift

**OffshoreBudgeting/View Models/CardsViewModel.swift**
- // MARK: - CardsLoadState
- // MARK: - CardsViewAlert
- // MARK: - CardsViewModel
- // MARK: Published State
- // MARK: Dependencies
- // MARK: Combine
- // MARK: Init
- // MARK: startIfNeeded()
- // MARK: refresh()
- // MARK: configureAndStartObserver()
- // MARK: addCard(name:theme:)
- // MARK: promptRename(for:)
- // MARK: rename(card:to:)
- // MARK: requestDelete(card:)
- // MARK: confirmDelete(card:)
- // MARK: edit(card:name:theme:)
- // MARK: reapplyThemes()

**OffshoreBudgeting/View Models/HomeViewModel.swift**
- // MARK: - BudgetLoadState
- // MARK: - HomeViewAlert
- // MARK: - BudgetSummary (View Model DTO)
- // MARK: Identity
- // MARK: Budget Basics
- // MARK: Variable Spend (Unplanned) by Category
- // MARK: Planned Expenses (line items attached to budget)
- // MARK: Income (date-based; no relationship)
- // MARK: Savings
- // MARK: Convenience
- // MARK: - Month (Helper)
- // MARK: start(of:)
- // MARK: end(of:)
- // MARK: range(for:)
- // MARK: - HomeViewModel
- // MARK: Published State
- // MARK: Dependencies
- // MARK: init()
- // MARK: startIfNeeded()
- // MARK: refresh()

**OffshoreBudgeting/View Models/CardDetailViewModel.swift**
- // MARK: - CardCategoryTotal
- // MARK: - CardExpense
- // MARK: - CardDetailLoadState
- // MARK: - CardDetailViewModel
- // MARK: Inputs
- // MARK: Services
- // MARK: Outputs
- // MARK: Init
- // MARK: load()

**OffshoreBudgeting/View Models/AddPlannedExpenseViewModel.swift**
- // MARK: - AddPlannedExpenseViewModel
- // MARK: Dependencies
- // MARK: Identity
- // MARK: Loaded Data
- // MARK: Form State
- // MARK: Init
- // MARK: load()
- // MARK: Validation
- // MARK: save()
- // MARK: Private fetch

**OffshoreBudgeting/View Models/SettingsViewModel.swift**
- // MARK: - SettingsViewModel
- // MARK: - Init
- // MARK: - Cross-Platform Colors
- // MARK: - SettingsIcon
- // MARK: - SettingsCard
- // MARK: - SettingsRow

**OffshoreBudgeting/View Models/AddUnplannedExpenseViewModel.swift**
- // MARK: - AddUnplannedExpenseViewModel
- // MARK: Dependencies
- // MARK: Identity
- // MARK: Loaded Data
- // MARK: Allowed filter (e.g., only cards tracked by a given budget)
- // MARK: Preselection
- // MARK: Live Updates
- // MARK: Form State
- // MARK: Init
- // MARK: load()
- // MARK: Validation
- // MARK: Parsed Amount
- // MARK: save()
- // MARK: Private fetch

**OffshoreBudgeting/View Models/AddBudgetViewModel.swift**
- // MARK: - AddBudgetViewModel
- // MARK: Inputs (bound to UI)
- // MARK: Loaded Data (Core Data)
- // MARK: Selections
- // MARK: Dependencies
- // MARK: Editing
- // MARK: Init
- // MARK: Validation
- // MARK: load()
- // MARK: save()
- // MARK: - Private (ADD)
- // MARK: - Private (EDIT)
- // MARK: Private fetch helpers

**OffshoreBudgeting/View Models/BudgetDetailsViewModel.swift**
- // MARK: - BudgetDetailsViewModel
- // MARK: Inputs
- // MARK: Core Data
- // MARK: Filter/Search/Sort
- // MARK: Date Window
- // MARK: Sort
- // MARK: Loaded data (raw)
- // MARK: Summary
- // MARK: Derived filtered/sorted
- // MARK: Init
- // MARK: Public API
- // MARK: - Fetch helpers

**OffshoreBudgeting/View Models/IncomeScreenViewModel.swift**
- // MARK: - IncomeScreenViewModel
- // MARK: Public, @Published
- // MARK: Private
- // MARK: Init
- // MARK: Titles
- // MARK: Loading
- // MARK: CRUD
- // MARK: Formatting
- // MARK: Events Summary
- // MARK: - Event Cache Management
- // MARK: - Currency NumberFormatter

**OffshoreBudgeting/Resources/CoreDataEntityChangeMonitor.swift**
- // MARK: - CoreDataEntityChangeMonitor
- // MARK: Private
- // MARK: Init

**OffshoreBudgeting/Resources/CoreDataListObserver.swift**
- // MARK: - CoreDataListObserver
- // MARK: Stored
- // MARK: Init
- // MARK: start()
- // MARK: stop()
- // MARK: NSFetchedResultsControllerDelegate

**OffshoreBudgeting/Resources/BudgetIncomeCalculator.swift**
- // MARK: - BudgetIncomeCalculator
- // MARK: Fetch
- // MARK: Sum
- // MARK: Totals Bucket
- // MARK: Helpers

**OffshoreBudgeting/Resources/Color+Hex.swift**
- // MARK: - Color + Hex
- // MARK: init?(hex:)

**OffshoreBudgeting/Resources/PlannedExpenseService+Templates.swift**
- // MARK: - PlannedExpenseService + Templates
- // MARK: Fetch Global Templates
- // MARK: Fetch Children
- // MARK: Ensure Child (Assign)
- // MARK: Remove Child (Unassign)
- // MARK: Child Lookup
- // MARK: Fetch Budgets (helper)
- // MARK: Delete Template + Children
- // MARK: Update Template + Propagate
- // MARK: Update Child + Optionally Parent/Future Siblings

**OffshoreBudgeting/Resources/RecurrenceRule.swift**
- // MARK: - Weekday
- // MARK: - RecurrenceRule
- // MARK: Builder Output
- // MARK: RRULE Generation
- // MARK: Parse (best-effort)
- // MARK: Utilities

**OffshoreBudgeting/Resources/SaveError.swift**
- // MARK: - SaveError
- // MARK: Cases
- // MARK: Identifiable
- // MARK: Presentation
- // MARK: Bridging
- // MARK: Pretty Printer for Core Data

**OffshoreBudgeting/Resources/CardItem+CoreDataBridge.swift**
- // MARK: - CardItem + Core Data Bridge
- // MARK: init(from:appearanceStore:)

**OffshoreBudgeting/Resources/NotificationName+Extensions.swift**
- // MARK: - App Notification Names
- // MARK: - dataStoreDidChange
- // MARK: - dataStoreDidChangeRemotely
- // MARK: - BudgetDetails Add Requests

**OffshoreBudgeting/Resources/HolographicMetallicText.swift**
- // MARK: - HolographicMetallicText
- // MARK: Inputs
- // MARK: Motion
- // MARK: Body
- // MARK: Base title (dark + readable across platforms)
- // MARK: Overlays (masked to text)
- // MARK: - Motion → Parameters
- // MARK: Metallic Overlay Opacity
- // MARK: Shine Overlay Opacity
- // MARK: Shine Intensity
- // MARK: Metallic Angle
- // MARK: Shine Angle

**OffshoreBudgeting/Resources/AddIncomeFormView+Lifecycle.swift**
- // MARK: - Eager Load Existing Income On Appear

**OffshoreBudgeting/Resources/UnifiedSwipeActions.swift**
- // MARK: - UnifiedSwipeConfig
- // MARK: Platform Defaults
- // MARK: - UnifiedSwipeCustomAction
- // MARK: - UnifiedSwipeActionsModifier
- // MARK: Buttons
- // MARK: - Label
- // MARK: - Helpers
- // MARK: - View Extension
- // MARK: - Helpers
- // MARK: - Color Helpers

**OffshoreBudgeting/Models/CardItem.swift**
- // MARK: - CardItem (UI Model)
- // MARK: Identity
- // MARK: Display
- // MARK: Identifiable

**OffshoreBudgeting/Systems/MetallicTextStyles.swift**
- UBTypography: cardTitleStatic, cardTitleShadowColor
- UBDecor: metallicSilverLinear, holographicGradient, holographicShine, metallicShine

**OffshoreBudgeting/Systems/AppSettings.swift**
- // MARK: - AppSettingsKeys

**OffshoreBudgeting/Systems/PlatformCapabilities.swift**
- // MARK: - Environment support

**OffshoreBudgeting/Systems/Compatibility.swift**
- // MARK: - View Modifiers (Cross-Platform)
- // MARK: ub_onChange(of:initial:)
- // MARK: ub_cardTitleShadow()
- // MARK: ub_compactDatePickerStyle()
- // MARK: ub_formStyleGrouped()
- // MARK: ub_pickerBackground()
- // MARK: ub_hideScrollIndicators()
- // MARK: ub_listStyleLiquidAware()
- // MARK: ub_preOS26ListRowBackground(_:)
- // MARK: - Internal Modifiers (List Styling)
- // MARK: - List Separators Helper
- // MARK: - Private Modifiers
  (Removed wrappers: ub_noAutoCapsAndCorrection, ub_decimalKeyboard, ub_tabNavigationTitle, ub_toolbarTitleInline, ub_toolbarTitleLarge, ub_sheetPadding)
  (Removed UBChromeGlassModifier and UBColor)

**OffshoreBudgeting/Systems/HomeHeaderLayoutEnvironment.swift**
- // MARK: - Environment Key

**OffshoreBudgeting/Systems/IncomeCalendarPalette.swift**
- // MARK: - Month title (e.g., "August 2025")
- // MARK: - Day cell with income summaries
- // MARK: - Weekday label (M T W T F S S)
- // MARK: - Weekdays row

**OffshoreBudgeting/Systems/DesignSystem+Motion.swift**
- // MARK: Card Background Tuning

**OffshoreBudgeting/Systems/DesignSystem.swift**
- // MARK: Platform Color Imports
- // MARK: - DesignSystem (Tokens)
- // MARK: Spacing (pts)
- // MARK: Corner Radii
- // MARK: Colors
- // MARK: System‑Aware Container Background
- // MARK: Chip and Pill Fills
  (Removed legacy Shadows and cardBackground helper)

// DS.Decor was removed; use MetallicTextStyles.swift

**OffshoreBudgeting/Systems/MotionSupport.swift**
- // MARK: - MotionMonitor
- // MARK: Singleton
- // MARK: Raw Motion (unscaled)
- // MARK: Smoothed / Scaled for display (use these for backgrounds)
- // MARK: Config
- // MARK: Provider
- // MARK: Init
- // MARK: start()
- // MARK: stop()
- // MARK: updateTuning(smoothing:scale:)

**OffshoreBudgeting/Systems/CardTheme.swift**
- // MARK: - Platform Color Bridge
- // MARK: - Helper: labelCGColor(_:)
- // MARK: - CardTheme
- // MARK: Display Name
- // MARK: Base Colors
- // MARK: Stripe Overlay Color (legacy compat)
- // MARK: Glow Color
- // MARK: Gradient (tilt-aware)
- // MARK: - BackgroundPattern
- // MARK: CardTheme → BackgroundPattern mapping
- // MARK: - CardTheme.Pattern Overlay
- // MARK: - Pattern Implementations (SwiftUI-only; iOS/macOS)
- // MARK: DiagonalStripesOverlay
- // MARK: CrossHatchOverlay
- // MARK: GridOverlay
- // MARK: DotsOverlay
- // MARK: NoiseOverlay

**OffshoreBudgeting/Systems/AppTheme.swift**
- // MARK: - Cloud Sync Infrastructure
- // MARK: - AppTheme
- // MARK: - AppTheme.GlassConfiguration
- // MARK: - Color Utilities
- // MARK: - ThemeManager

**OffshoreBudgeting/Systems/CardAppearanceStore.swift**
- // MARK: - CardAppearanceStore
- // MARK: Singleton
- // MARK: Storage Backbone
- // MARK: Init
- // MARK: load()
- // MARK: save()
- // MARK: theme(for:)
- // MARK: setTheme(_:for:)
- // MARK: removeTheme(for:)

**OffshoreBudgeting/Views/PresetsView.swift**
- // MARK: - PresetsView
- // MARK: Dependencies
- // MARK: State
- // MARK: Body
- // MARK: Empty State — standardized with UBEmptyState (same as Home/Cards)
- // MARK: Non-empty List
- // MARK: Data lifecycle
- // MARK: Add Preset Sheet
- // MARK: Assign Budgets Sheet
- // MARK: Edit Template Sheet
- // MARK: - Actions
- // MARK: - AddGlobalPlannedExpenseSheet
- // MARK: Callbacks
- // MARK: Env
- // MARK: Body
- // MARK: - Array Safe Indexing
- // MARK: - ViewModel + Helpers
- // MARK: - PresetListItem
- // MARK: Identity
- // MARK: Display

**OffshoreBudgeting/Views/CustomRecurrenceEditorView.swift**
- // MARK: - CustomRecurrence
- // MARK: - CustomRecurrenceEditorView
- // MARK: Inputs
- // MARK: State
- // MARK: Init
- // MARK: Body
- // MARK: Subviews
- // MARK: - AddIncomeFormViewModel (Custom Hook)

**OffshoreBudgeting/Views/SettingsView.swift**
- // MARK: - SettingsView
- // MARK: Dependencies
- // MARK: - Helpers
- // MARK: General Hero Card
- // MARK: Appearance Card
- // MARK: Sync Card (disabled)
- // MARK: Calendar Card
- // MARK: Presets Card
- // MARK: Expenses Card (with sub-page)
- // MARK: Help Card
- // MARK: Onboarding Card
- // MARK: Reset Card
- // MARK: - Platform-Safe Modifiers
- // MARK: applyInlineNavTitleOnIOS()

**OffshoreBudgeting/Views/RenameCardSheet.swift**
- // MARK: - RenameCardSheet
- // MARK: State
- // MARK: body
- // MARK: Name field
- // MARK: Helpers

**OffshoreBudgeting/Views/PresetRowView.swift**
- // MARK: - PresetRowView
- // MARK: Inputs
- // MARK: Body
- // MARK: Left Column (Title + Planned/Actual)
- // MARK: Right Column (Assigned Budgets + Next Date)
- // MARK: - LabeledAmountBlock

**OffshoreBudgeting/Views/ExpenseCategoryManagerView.swift**
- // MARK: - ExpenseCategoryManagerView
- // MARK: Dependencies
- // MARK: Sorting (extracted to avoid heavy type inference)
- // MARK: Fetch Request
- // MARK: UI State
- // MARK: - Body
- // MARK: - Row Builders
- // MARK: - Empty State
- // MARK: - CRUD
- // MARK: - Availability Helpers
- // MARK: - ExpenseCategoryEditorSheet
- // MARK: Environment
- // MARK: State
- // MARK: Callback
- // MARK: Init
- // MARK: Body
- // MARK: Helper: Color -> Hex
- // MARK: - ColorCircle
- // MARK: Utility

**OffshoreBudgeting/Views/UBEmptyState.swift**
- // MARK: - UBEmptyState
- // MARK: Content
- // MARK: Actions
- // MARK: Layout
- // MARK: init(...)
- // MARK: Body
- // MARK: Icon
- // MARK: Title
- // MARK: Message
- // MARK: Primary CTA (optional)
- // MARK: Primary Button Helpers

**OffshoreBudgeting/Views/HomeView.swift**
- // MARK: - HomeView
- // MARK: State & ViewModel
- // MARK: Add Budget Sheet
- // MARK: Header Layout
- // MARK: Body
- // MARK: ADD SHEET — present new budget UI for the selected period
- // MARK: Empty-state: Create budget (+)
- // MARK: New: Standalone glass buttons for empty state header
- // MARK: Sheets & Alerts
- // MARK: Content Container
- // MARK: Empty Period Shell (replaces generic empty state)
- // MARK: Helpers
- // MARK: Empty-period CTA helpers
- // MARK: - Home Header Primary Summary
- // MARK: - Fallback header when no budget exists
- // MARK: - Zero summary grid for empty periods
- // MARK: - Section header + total row
- // MARK: - Empty shell helpers (glass capsule + segmented sizing)
- // MARK: - Home Header Summary
- // MARK: - Header Control Width Matching

**OffshoreBudgeting/Views/AddBudgetView.swift**
- // MARK: - AddBudgetView
- // MARK: Environment
- // MARK: Inputs
- // MARK: VM
- // MARK: Local UI State
- // MARK: Init (ADD)
- // MARK: Init (EDIT)
- // MARK: Body
- // MARK: Standardized Sheet Chrome
- // MARK: Form Content (standardized)
- // MARK: Actions

**OffshoreBudgeting/Views/CardTileView.swift**
- // MARK: - CardTileView
- // MARK: Inputs
- // MARK: Layout
- // MARK: Body
- // MARK: Card Background (STATIC gradient + pattern)
- // MARK: Title (Metallic shimmer stays)
- // MARK: - Computed Views
- // MARK: Background Gradient (STATIC)
- // MARK: Selection Ring (always visible, not clipped)
- // MARK: Selection Glow (soft, outside)
- // MARK: Thin Edge
- // MARK: Title builder

**OffshoreBudgeting/Views/NoCardTile.swift**
- // MARK: Inputs
- // MARK: Layout
- // MARK: - Overlays

**OffshoreBudgeting/Views/AddPlannedExpenseView.swift**
- // MARK: - AddPlannedExpenseView
- // MARK: Inputs
- // MARK: State
- // MARK: Layout
- // MARK: Init
- // MARK: Body
- // MARK: Card Selection
- // MARK: Budget Assignment
- // MARK: Category Selection
- // MARK: Individual Fields
- // MARK: Use in future budgets?
- // MARK: Lifecycle
- // MARK: Actions
- // MARK: - CategoryChipsRow
- // MARK: - AddCategoryPill
- // MARK: - CategoryChip

**OffshoreBudgeting/Views/IncomeEditorView.swift**
- // MARK: - IncomeEditorMode
- // MARK: - IncomeEditorAction
- // MARK: - Editor Form Model
- // MARK: RecurrenceOption
- // MARK: - IncomeEditorView
- // MARK: Inputs
- // MARK: State
- // MARK: Init
- // MARK: Body
- // MARK: Details
- // MARK: Recurrence
- // MARK: Labels
- // MARK: Validation
- // MARK: Amount Field
- // MARK: Save Handler
- // MARK: Initial Form

**OffshoreBudgeting/Views/RecurrencePickerView.swift**
- // MARK: - RecurrencePickerView
- // MARK: Bindings
- // MARK: Local State (UI)
- // MARK: Preset Options
- // MARK: Init
- // MARK: Body
- // MARK: Behavior
- // MARK: Subviews

**OffshoreBudgeting/Views/AddCardFormView.swift**
- // MARK: - AddCardFormView
- // MARK: Mode
- // MARK: Configuration
- // MARK: Inputs
- // MARK: Init
- // MARK: Local State
- // MARK: Computed
- // MARK: - Body
- // MARK: Standardized Sheet Chrome (matches Add Budget)
- // MARK: Form Content (standardized)
- // MARK: Cross-platform placeholder handling
- // MARK: - Actions
- // MARK: saveTapped()
- // MARK: - ThemeSwatch

**OffshoreBudgeting/Views/CardPickerRow.swift**
- // MARK: - CardPickerRow
- // MARK: Inputs
- // MARK: Layout
- // MARK: Body
- // MARK: Bridge Core Data → UI model
- // MARK: On Tap → Select for Expense

**OffshoreBudgeting/Views/CardPickerItemTile.swift**
- // MARK: - CardPickerItemTile
- // MARK: Inputs
- // MARK: Layout Constants
- // MARK: Body

**OffshoreBudgeting/Views/HelpView.swift**
- // MARK:` comments across the codebase so users can
- // MARK: Getting Started
- // MARK: Core Screens
- // MARK: Tips & Tricks
- // MARK: Getting Started
- // MARK: Core Screens
- // MARK: Tips & Tricks
- // MARK: Getting Started
- // MARK: Core Screens
- // MARK: Tips & Tricks
- // MARK: - Pages

**OffshoreBudgeting/Views/IncomeView.swift**
- // MARK: - IncomeView
- // MARK: State
- // MARK: Environment
- // MARK: View Model
- // MARK: Calendar
- // MARK: Body
- // MARK: Present Add Income Form
- // MARK: Present Edit Income Form (triggered by non-nil `editingIncome`)
- // MARK: - Calendar Section
- // MARK: Double-click calendar to add income (macOS)
- // MARK: - Weekly Summary Bar
- // MARK: - Selected Day Section (WITH swipe to delete & edit)
- // MARK: Section Title — Selected Day
- // MARK: - Calendar Navigation Helpers
- // MARK: - Edit Flow Helpers
- // MARK: - Formatting Helpers
- // MARK: - Delete Handler
- // MARK: - IncomeRow
- // MARK: Properties
- // MARK: Body

**OffshoreBudgeting/Views/AddUnplannedExpenseView.swift**
- // MARK: - AddUnplannedExpenseView
- // MARK: Inputs
- // MARK: State
- // MARK: - Layout
- // MARK: Init
- // MARK: Body
- // MARK: Card Picker (horizontal)
- // MARK: Category Chips Row
- // MARK: Individual Fields
- // MARK: - trySave()
- // MARK: - CategoryChipsRow
- // MARK: Binding
- // MARK: Environment
- // MARK: Live Fetch
- // MARK: Local State
- // MARK: Static Add Button (doesn't scroll)
- // MARK: Scrolling Chips
- // MARK: - AddCategoryPill
- // MARK: - CategoryChip

**OffshoreBudgeting/Views/EditSheetScaffold.swift**
- // MARK: - UBPresentationDetent (compat wrapper)
- // MARK: - EditSheetScaffold
- // MARK: Inputs
- // MARK: Environment
- // MARK: Init
- // MARK: body
- // MARK: Standard sheet behavior (platform-aware)
- // MARK: - Subviews
- // MARK: Row Background
- // MARK: Detent selection binding (iOS only)
- // MARK: - Detents application helper

**OffshoreBudgeting/Views/BudgetDetailsView.swift**
- // MARK: - BudgetDetailsView
- // MARK: Inputs
- // MARK: View Model
- // MARK: Theme
- // MARK: UI State
- // MARK: Layout
- // MARK: Init
- // MARK: Body
- // MARK: Lists
- // MARK: Add Sheets
- // MARK: Helpers
- // MARK: - Scrolling List Header Content
- // MARK: - Combined Budget Header Grid (aligns all numeric totals)
- // MARK: - SummarySection
- // MARK: - CategoryTotalsRow
- // MARK: - FilterBar (unchanged API)
- // MARK: - Shared Glass Capsule Container
- // MARK: - PlannedListFR (List-backed; swipe enabled)
- // MARK: Environment for deletes
- // MARK: Compact empty state (single Add button)

**OffshoreBudgeting/Views/PresetBudgetAssignmentSheet.swift**
- // MARK: - PresetBudgetAssignmentSheet
- // MARK: Environment
- // MARK: Inputs
- // MARK: State
- // MARK: Body
- // MARK: Toolbar Buttons
- // MARK: - Navigation container (iOS 16+/macOS 13+ NavigationStack; older NavigationView)
- // MARK: - Load
- // MARK: - Membership Utilities
- // MARK: - Save
- // MARK: - Formatting

**OffshoreBudgeting/Views/UBFormSection.swift**
- // MARK: Inputs
- // MARK: Init
- // MARK: Body

**OffshoreBudgeting/Views/CardsView.swift**
- // MARK: - CardsView
- // MARK: State & Dependencies
- // MARK: Selection State
- // MARK: Grid Layout
- // MARK: Layout Constants
- // MARK: Body
- // MARK: Start observing when view appears
- // MARK: App Toolbar
- // MARK: Add Sheet
- // MARK: Edit Sheet
- // MARK: Alerts
- // MARK: - Content View (Type-Safe)
- // MARK: Loading View
- // MARK: Empty View
- // MARK: Grid View
- // MARK: On Tap → Select Card
- // MARK: Keep selection valid when dataset changes (delete/rename)
- // MARK: - Tiny shimmer for placeholder

**OffshoreBudgeting/Views/OnboardingView.swift**
- // MARK: - OnboardingView
- // MARK: AppStorage
- // MARK: Step
- // MARK: - Body
- // MARK: - WelcomeStep
- // MARK: - ThemeStep
- // MARK: ThemePreviewTile
- // MARK: - CardsStep
- // MARK: - Navigation container compatibility
- // MARK: - PresetsStep
- // MARK: - CloudSyncStep
- // MARK: - CategoriesStep
- // MARK: - Navigation container compatibility
- // MARK: - LoadingStep
- // MARK: - Shared Components

**OffshoreBudgeting/Views/CardDetailView.swift**
- // MARK: - CardDetailView
- // MARK: Inputs
- // MARK: State
- // MARK: Init
- // MARK: Body
- // MARK: content
- // MARK: navigationContainer
- // MARK: totalsSection
- // MARK: categoryBreakdown
- // MARK: expensesList
- // MARK: - ExpenseRow
- // MARK: - Shared Toolbar Icon

**OffshoreBudgeting/Views/AddIncomeFormView.swift**
- // MARK: - AddIncomeFormView
- // MARK: Environment
- // MARK: Inputs
- // MARK: State
- // MARK: Init
- // MARK: Body
- // MARK: Standardized Sheet Chrome
- // MARK: Form Content
- // MARK: Eager load (edit) / Prefill date (add)
- // MARK: Sections
- // MARK: Type
- // MARK: Source
- // MARK: Amount
- // MARK: First Date
- // MARK: Recurrence
- // MARK: Save
- // MARK: Utilities

**OffshoreBudgeting/Views/Components/CalendarNavigationButtonStyle.swift**
- // MARK: - Layers
- // MARK: - Colors

**OffshoreBudgeting/Views/Components/RootHeaderActions.swift**
- // MARK: - Shared Metrics
- // MARK: - Icon Content
- // MARK: - Action Button Style
- // MARK: - Optional Accessibility Identifier
- // MARK: - Header Glass Controls (iOS + macOS)
- // MARK: - Convenience Icon Button

**OffshoreBudgeting/Views/Components/PeriodNavigationControl.swift**
- // MARK: - Properties
- // MARK: - Init
- // MARK: - Body
- // MARK: - Typography Helpers
- // MARK: - Button Styling Helpers

**OffshoreBudgeting/Views/Components/RootTabHeader.swift**
- // MARK: Properties
- // MARK: Init
- // MARK: Body

**OffshoreBudgeting/Views/Components/RootTabPageScaffold.swift**
- // MARK: Scroll Behaviour
- // MARK: Width Constraints
- // MARK: Inputs
- // MARK: Environment
- // MARK: State
- // MARK: Init
- // MARK: Body
- // MARK: Stack Content
- // MARK: Height Tracking
- // MARK: - RootTabPageProxy
- // MARK: - Preference Infrastructure
- // MARK: - Padding Helpers

**OffshoreBudgeting/Services/CoreDataService.swift**
- // MARK: - CoreDataService
- // MARK: Singleton
- // MARK: Configuration
- // MARK: Load State
- // MARK: Change Observers
- // MARK: Persistent Container
- // MARK: Store Options
- // MARK: Contexts
- // MARK: Lifecycle
- // MARK: Post-Load Configuration
- // MARK: Change Observation
- // MARK: Save
- // MARK: Background Task
- // MARK: Await Stores Loaded (Tiny helper)
- // MARK: - Reset
- // MARK: - Cloud Sync Preferences
- // MARK: - Private Helpers

**OffshoreBudgeting/Services/CardService.swift**
- // MARK: - CardService
- // MARK: Properties
- // MARK: Init
- // MARK: fetchAllCards(sortedByName:)
- // MARK: fetchCards(forBudgetID:)
- // MARK: findCard(byID:)
- // MARK: countCards(named:)
- // MARK: createCard(name:ensureUniqueName:attachToBudgetIDs:)
- // MARK: renameCard(_:to:)
- // MARK: updateCard(_:name:)
- // MARK: deleteCard(_:)
- // MARK: deleteAllCards()
- // MARK: attachCard(_:toBudgetsWithIDs:)
- // MARK: detachCard(_:fromBudgetsWithIDs:)
- // MARK: replaceCard(_:budgetsWithIDs:)

**OffshoreBudgeting/Services/BudgetService.swift**
- // MARK: - BudgetService
- // MARK: Properties
- // MARK: fetchAllBudgets(sortByStartDateDescending:)
- // MARK: findBudget(byID:)
- // MARK: fetchActiveBudget(on:)
- // MARK: createBudget(...)
- // MARK: updateBudget(_:name:dates:isRecurring:recurrenceType:recurrenceEndDate:parentID:)
- // MARK: deleteBudget(_:)
- // MARK: projectedDates(for:in:)

**OffshoreBudgeting/Services/ExpenseCategoryService.swift**
- // MARK: - ExpenseCategoryService
- // MARK: Properties
- // MARK: fetchAllCategories(sortedByName:)
- // MARK: findCategory(byID:)
- // MARK: findCategory(named:)
- // MARK: addCategory(name:color:ensureUniqueName:)
- // MARK: updateCategory(_:name:color:)
- // MARK: deleteCategory(_:)
- // MARK: deleteAllCategories()

**OffshoreBudgeting/Services/RecurrenceEngine.swift**
- // MARK: - Keyword Handling
- // MARK: - RRULE Handling
- // MARK: - Core Stride Helpers
- // MARK: - Utilities
- // MARK: - Persistence Helpers (Income)

**OffshoreBudgeting/Services/CloudAccountStatusProvider.swift**
- // MARK: Shared Instance
- // MARK: Availability State
- // MARK: Init
- // MARK: Public API
- // MARK: Private Helpers
- // MARK: - CloudAvailabilityProviding

**OffshoreBudgeting/Services/PlannedExpenseService.swift**
- // MARK: - PlannedExpenseServiceError
- // MARK: - PlannedExpenseService
- // MARK: Singleton (for convenience across SwiftUI)
- // MARK: Properties
- // MARK: Init
- // MARK: - FETCH
- // MARK: fetchAll(sortedByDateAscending:)
- // MARK: find(byID:)
- // MARK: fetchForBudget(_:sortedByDateAscending:)
- // MARK: fetchForBudget(_:in:sortedByDateAscending:)
- // MARK: fetchForCard(_:sortedByDateAscending:)
- // MARK: fetchForCard(_:in:sortedByDateAscending:)
- // MARK: - CREATE
- // MARK: create(inBudgetID:titleOrDescription:plannedAmount:actualAmount:transactionDate:isGlobal:globalTemplateID:)
- // MARK: createGlobalTemplate(titleOrDescription:plannedAmount:defaultTransactionDate:)
- // MARK: instantiateTemplate(_:intoBudgetID:on:)
- // MARK: duplicate(_:intoBudgetID:on:)
- // MARK: - UPDATE
- // MARK: update(_:titleOrDescription:plannedAmount:actualAmount:transactionDate:isGlobal:globalTemplateID:)
- // MARK: move(_:toBudgetID:)

**OffshoreBudgeting/Services/IncomeService.swift**
- // MARK: - RecurrenceScope
- // MARK: - IncomeService
- // MARK: Types
- // MARK: Properties
- // MARK: Init
- // MARK: - CRUD
- // MARK: fetchAllIncomes(sortedByDateAscending:)
- // MARK: fetchIncomes(in:)
- // MARK: fetchIncomes(on:)
- // MARK: findIncome(byID:)
- // MARK: createIncome(...)
- // MARK: updateIncome(_:scope:...)
- // MARK: deleteIncome(_:scope:)
- // MARK: deleteAllIncomes()
- // MARK: - Calendar Helpers
- // MARK: events(in:includeProjectedRecurrences:)
- // MARK: eventsByDay(in:)
- // MARK: eventsByDay(inMonthContaining:)
- // MARK: totalAmount(in:includePlanned:)
- // MARK: - Private: Recurrence & Date Utilities

**OffshoreBudgeting/Services/UnplannedExpenseService.swift**
- // MARK: - UnplannedExpenseService
- // MARK: Types
- // MARK: Properties
- // MARK: Init
- // MARK: - FETCH
- // MARK: fetchAll(sortedByDateAscending:)
- // MARK: find(byID:)
- // MARK: fetchForCard(_:in:sortedByDateAscending:)
- // MARK: fetchForCategory(_:in:sortedByDateAscending:)
- // MARK: fetchForBudget(_:in:sortedByDateAscending:)
- // MARK: - CREATE
- // MARK: create(description:amount:date:cardID:categoryID:recurrence:recurrenceEnd:secondBiMonthlyDay:secondBiMonthlyDate:parentID:)
- // MARK: - UPDATE
- // MARK: update(_:description:amount:date:cardID:categoryID:recurrence:recurrenceEnd:secondBiMonthlyDay:secondBiMonthlyDate:parentID:)
- // MARK: - DELETE
- // MARK: delete(_:cascadeChildren:)
- // MARK: deleteAllForCard(_:)
- // MARK: - TOTALS
- // MARK: totalForCard(_:in:)
- // MARK: totalForBudget(_:in:)

**OffshoreBudgeting/Services/Repository/CoreDataRepository.swift**
- // MARK: - CoreDataStackProviding
- // MARK: - CoreDataService + CoreDataStackProviding
- // MARK: - CoreDataRepository
- // MARK: Properties
- // MARK: Init
- // MARK: fetchAll(...)
- // MARK: fetchFirst(...)
- // MARK: count(...)
- // MARK: create(configure:)
- // MARK: delete(_:)
- // MARK: deleteAll(predicate:)
- // MARK: saveIfNeeded()
- // MARK: performBackgroundTask(_:)

## UI guidelines

- Align header pills, grids, and info panels using shared layout environment values when present.
- Keep text sizing, spacing, and padding consistent with existing design tokens.
- Avoid hard-coded device checks when layout modifiers can adapt.
- Ensure that iOS 26/iPadOS26/macOS 26 Liquid Glass is prioritized and provide legacy fallback for older OSes. The app supports as low as iOS/iPadOS 15.4 and macOS 15.4; due to this, Liquid Glass should only be for OS 26 and then older, legacy OS versions have their UI elements that are consistent with their current OS.

## Core Data and model notes

- Respect existing entity and relationship names. Do not change the schema unless asked.
- When adding fetch logic, centralize it in service files if that pattern exists.

## Logging and error handling

- Use existing helpers for alerts and logs if present. Do not introduce print spam.

## Commit style for tool-generated changes

- Conventional subject: `feat(view): short description` or `fix(service): short description`.
- Body lists files touched and a brief rationale.
