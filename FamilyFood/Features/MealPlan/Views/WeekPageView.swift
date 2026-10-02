import SwiftUI

struct WeekPageView: View {
    let slots: [DaySlot]
    let kitaMealsForWeekday: (Weekday) -> [(childName: String, meal: String, color: Color)]
    let recipeForMeal: (PlannedMeal) -> RecipeModel?
    let isToday: (Weekday) -> Bool
    let onToggleMealType: (Weekday) -> Void
    let onRowTap: (DaySlot) -> Void
    let onClearMeal: (Weekday) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(slots) { slot in
                    DaySlotRow(
                        slot: slot,
                        kitaMeals: kitaMealsForWeekday(slot.weekday),
                        recipe: slot.meal.flatMap(recipeForMeal),
                        isToday: isToday(slot.weekday),
                        onToggleMealType: { onToggleMealType(slot.weekday) },
                        onTap: { onRowTap(slot) }
                    )
                    .padding(.horizontal, AppTheme.Spacing.s24)
                    .contextMenu {
                        Button(role: .destructive) {
                            onClearMeal(slot.weekday)
                        } label: {
                            Label("Gericht entfernen", systemImage: "trash")
                        }
                    }
                    // Full-width hairline in the design-system divider color.
                    Rectangle()
                        .fill(AppTheme.Colors.divider)
                        .frame(height: 1)
                }
            }
        }
    }
}
