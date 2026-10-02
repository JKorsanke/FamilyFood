import SwiftUI

struct DaySlotRow: View {
    let slot: DaySlot
    let kitaMeals: [(childName: String, meal: String, color: Color)]
    let recipe: RecipeModel?
    let isToday: Bool
    let onToggleMealType: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.s16) {
            dayLabel

            VStack(alignment: .leading, spacing: AppTheme.Spacing.s2) {
                // KiGa rows — weekdays only, one per active Kita plan
                if !slot.weekday.isWeekend {
                    ForEach(Array(kitaMeals.enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.s8) {
                            // Per-child color kept (decision A); "· KITA" overline layered on top.
                            Text("\(entry.childName) · KITA")
                                .appText(.overline)
                                .foregroundStyle(entry.color)
                                .padding(.vertical, AppTheme.Spacing.s2)
                                .padding(.horizontal, AppTheme.Spacing.s8)
                                .background(entry.color.opacity(0.15))
                                .clipShape(Capsule())
                            Text(entry.meal)
                                .appText(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Family meal row
                Button(action: onTap) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.s12) {
                        mealTypePill

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s2) {
                            mealNameView
                            if let metadataLine {
                                Text(metadataLine)
                                    .appText(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppTheme.Spacing.s14)
    }

    // MARK: - Day label + today indicator

    private var dayLabel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s6) {
            Text(slot.weekday.shortName)
                .appText(.headline)
                .foregroundStyle(isToday ? AppTheme.Colors.accent : AppTheme.Colors.textPrimary)
            if isToday {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 44, alignment: .leading)
    }

    // MARK: - Meal-type pill

    @ViewBuilder
    private var mealTypePill: some View {
        if slot.weekday.isWeekend {
            // Weekend: accent pill, tap to toggle Mittag/Abend (decision C — meal type is the label, not the color).
            Button(action: onToggleMealType) {
                Text(slot.mealType.displayName)
                    .appText(.overline)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.s2)
                    .padding(.horizontal, AppTheme.Spacing.s8)
                    .background(AppTheme.Colors.accentTint)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            // Weekday dinner: neutral gray pill.
            Text(slot.mealType.displayName)
                .appText(.overline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.vertical, AppTheme.Spacing.s2)
                .padding(.horizontal, AppTheme.Spacing.s8)
                .background(AppTheme.Colors.neutralTint)
                .clipShape(Capsule())
        }
    }

    private var metadataLine: String? {
        guard let recipe else { return nil }
        var parts: [String] = []
        if let mins = recipe.displayTotalTime { parts.append("\(mins) Min") }
        if recipe.dietStyle != .unknown { parts.append(recipe.dietStyle.displayName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var mealNameView: some View {
        if slot.meal?.isExtern == true {
            Text("Extern")
                .appText(.label)
                .italic()
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if slot.meal?.isAbendbrot == true {
            Text("Abendbrot")
                .appText(.label)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(slot.meal?.name ?? "Mahlzeit hinzufügen…")
                .appText(.label)
                .foregroundStyle(slot.isEmpty ? AppTheme.Colors.textFaded : AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
