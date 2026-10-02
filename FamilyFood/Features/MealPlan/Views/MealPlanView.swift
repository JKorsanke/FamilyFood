import SwiftUI
import SwiftData

struct MealPlanView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var viewModel = MealPlanViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [RecipeModel]
    @AppStorage("userSettings") private var settings: UserSettings = UserSettings()
    @State private var actionSlot: DaySlot?
    @State private var scrolledWeek: WeekKey? = .current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.weekKeys, id: \.self) { week in
                            WeekPageView(
                                slots: slots(for: week),
                                kitaMealsForWeekday: { weekday in
                                    kitaMeals(for: weekday, week: week)
                                },
                                recipeForMeal: { meal in
                                    recipes.first { $0.id == meal.recipeId }
                                },
                                isToday: { weekday in week.isToday(weekday) },
                                onToggleMealType: { weekday in viewModel.toggleMealType(for: weekday) },
                                onRowTap: { slot in actionSlot = slot },
                                onClearMeal: { weekday in viewModel.clearMeal(for: weekday) }
                            )
                            .containerRelativeFrame(.horizontal)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrolledWeek)
                .scrollIndicators(.hidden)
                .onChange(of: scrolledWeek) { _, newWeek in
                    guard let newWeek else { return }
                    viewModel.setCenteredWeek(newWeek)
                    viewModel.applyWarmMealLayout(to: newWeek, settings: settings)
                }
            }
            .task {
                viewModel.applyWarmMealLayout(to: .current, settings: settings)
            }
            .onChange(of: settings.warmMealDays) { _, _ in
                viewModel.refreshWarmMealLayout(settings: settings)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $actionSlot) { slot in
            MealActionSheet(
                slot: slot,
                allSlots: viewModel.plan.slots,
                weeklyPlanRecipeIds: Set(viewModel.plan.slots.compactMap { $0.meal?.recipeId }),
                onAssignRecipe: { recipe in
                    viewModel.assignRecipe(recipe, to: slot.weekday, modelContext: modelContext)
                },
                onSetBrotzeit: {
                    viewModel.setBrotzeit(for: slot.weekday)
                },
                onSetExtern: {
                    viewModel.setExtern(for: slot.weekday)
                },
                onClear: {
                    viewModel.clearMeal(for: slot.weekday)
                },
                onMove: { targetWeekday in
                    viewModel.moveMeal(from: slot.weekday, to: targetWeekday)
                }
            )
        }
    }

    // MARK: - Header (editorial header replaces the iOS large title)

    private var header: some View {
        VStack(spacing: 0) {
            topBar
            weekSwitcher
        }
    }

    /// Row 1: "Heute" return on the left, whisk generate on the right.
    private var topBar: some View {
        HStack(spacing: 0) {
            // Always shown: active accent off-week (returns to today), disabled/faded on the
            // current week — present so the user sees where they are.
            Button("Heute") {
                withAnimation { scrolledWeek = .current }
            }
            .appText(.label)
            .fontWeight(.semibold)
            .foregroundStyle(viewModel.isCurrentWeek ? AppTheme.Colors.textFaded : AppTheme.Colors.accent)
            .disabled(viewModel.isCurrentWeek)
            Spacer(minLength: 0)
            Button {
                viewModel.generatePlan(
                    recipes: recipes,
                    kitaPlans: store.kitaPlans,
                    settings: settings,
                    modelContext: modelContext
                )
            } label: {
                // Illustration glyph (whisk active, spoon swappable via
                // MealPlanGenerateIcon.current). Template + accent matches FFOnboardingIllustration.
                Image(Artwork.name(MealPlanGenerateIcon.current.assetName))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: MealPlanGenerateIcon.current.size.width,
                           height: MealPlanGenerateIcon.current.size.height)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 40, height: 40)   // tap slot
            }
            .accessibilityLabel("Generieren")
        }
        .padding(.horizontal, AppTheme.Spacing.s24)
        .padding(.vertical, AppTheme.Spacing.s20)
    }

    /// Row 2: chevrons flanking the eyebrow + headline date.
    private var weekSwitcher: some View {
        HStack(spacing: 0) {
            chevronButton(.left) {
                guard let current = scrolledWeek else { return }
                withAnimation { scrolledWeek = current.advanced(by: -1) }
            }
            Spacer(minLength: 0)
            VStack(spacing: AppTheme.Spacing.s6) {
                Text(viewModel.weekEyebrow)
                    .appText(.eyebrow)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(viewModel.weekDateRange)
                    .appText(.display)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Spacer(minLength: 0)
            chevronButton(.right) {
                guard let current = scrolledWeek else { return }
                withAnimation { scrolledWeek = current.advanced(by: 1) }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.s24)
        .padding(.top, AppTheme.Spacing.s16)
        .padding(.bottom, AppTheme.Spacing.s20)
    }

    private func chevronButton(_ direction: Chevron.Direction, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chevron(direction: direction)
                .stroke(AppTheme.Colors.textSecondary,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 16)
                .frame(width: 32, height: 32)   // tap slot
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slot lookup

    private func slots(for week: WeekKey) -> [DaySlot] {
        week == viewModel.plan.weekKey
            ? viewModel.plan.slots
            : viewModel.plan(for: week).slots
    }

    // MARK: - Kita meal lookup

    private func kitaMeals(for weekday: Weekday, week: WeekKey) -> [(childName: String, meal: String, color: Color)] {
        guard !weekday.isWeekend else { return [] }
        return store.kitaPlans.compactMap { kita in
            guard KitaWeekMatcher.matches(kita, weekStart: week.startDate) else { return nil }
            let day: KitaMealPlan.Day
            switch weekday {
            case .monday:    day = kita.monday
            case .tuesday:   day = kita.tuesday
            case .wednesday: day = kita.wednesday
            case .thursday:  day = kita.thursday
            case .friday:    day = kita.friday
            default: return nil
            }
            guard let mealText = day.meal else { return nil }
            if let childId = kita.childId,
               let child = settings.children.first(where: { $0.id == childId }) {
                return (childName: child.name, meal: mealText, color: ChildColor.color(for: childId))
            } else {
                return (childName: "KiGa", meal: mealText, color: .orange)
            }
        }
    }
}

/// Thin stroked week-switcher chevron — 1.5pt round-cap glyph from the Meal-Plan-New design,
/// which an SF Symbol can't reproduce exactly (its weight is tied to font weight, not a pt value).
private struct Chevron: Shape {
    enum Direction { case left, right }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .left:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return path
    }
}
