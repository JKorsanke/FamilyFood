import SwiftUI
import SwiftData

struct MealActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecipes: [RecipeModel]

    let slot: DaySlot
    let allSlots: [DaySlot]
    let weeklyPlanRecipeIds: Set<UUID>
    let onAssignRecipe: (RecipeModel) -> Void
    let onSetBrotzeit: () -> Void
    let onSetExtern: () -> Void
    let onClear: () -> Void
    let onMove: (Weekday) -> Void

    @State private var showingPicker = false
    @State private var showingSuggestions = false
    @State private var showingRecipe = false
    @State private var showingMove = false
    @State private var didCompleteAction = false

    private var currentRecipe: RecipeModel? {
        guard let id = slot.meal?.recipeId else { return nil }
        return allRecipes.first { $0.id == id }
    }

    private var suggestions: [RecipeModel] {
        Array(allRecipes.filter { $0.isFavourite && !weeklyPlanRecipeIds.contains($0.id) }.prefix(3))
    }

    private var headerTitle: String {
        guard let meal = slot.meal else { return "Kein Gericht" }
        switch meal.kind {
        case .extern:           return "Extern"
        case .abendbrot:        return "Abendbrot"
        case .recipe, .custom:  return meal.name
        }
    }

    private enum SlotState { case empty, filled, brotzeit, extern }

    private var slotState: SlotState {
        guard let meal = slot.meal else { return .empty }
        switch meal.kind {
        case .extern:           return .extern
        case .abendbrot:        return .brotzeit
        case .recipe, .custom:  return .filled
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider()
                actionsSection
                Spacer()
            }
            .navigationDestination(isPresented: $showingRecipe) {
                if let recipe = currentRecipe {
                    RecipeDetailView(recipe: recipe)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.resizes)
        .sheet(isPresented: $showingPicker) {
            RecipePickerView(recipes: allRecipes) { recipe in
                didCompleteAction = true
                onAssignRecipe(recipe)
            }
        }
        .onChange(of: showingPicker) { _, isShowing in
            if !isShowing, didCompleteAction {
                didCompleteAction = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingSuggestions) {
            FavoriteSuggestionsSheet(suggestions: suggestions) { recipe in
                didCompleteAction = true
                onAssignRecipe(recipe)
            }
        }
        .onChange(of: showingSuggestions) { _, isShowing in
            if !isShowing, didCompleteAction {
                didCompleteAction = false
                dismiss()
            }
        }
        .sheet(isPresented: $showingMove) {
            MoveMealSheet(sourceSlot: slot, allSlots: allSlots) { weekday in
                didCompleteAction = true
                onMove(weekday)
            }
        }
        .onChange(of: showingMove) { _, isShowing in
            if !isShowing, didCompleteAction {
                didCompleteAction = false
                dismiss()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(slot.weekday.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(headerTitle)
                .font(.headline)
        }
        .padding()
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            if currentRecipe != nil {
                actionRow("Rezept ansehen") { showingRecipe = true }
                Divider().padding(.leading)
            }

            switch slotState {
            case .filled:
                Group {
                    actionRow("Anderes Gericht vorschlagen") { showingSuggestions = true }
                    Divider().padding(.leading)
                    actionRow("Auf anderen Tag verschieben") { showingMove = true }
                    Divider().padding(.leading)
                    actionRow("Abendbrot einplanen") { onSetBrotzeit(); dismiss() }
                    Divider().padding(.leading)
                    actionRow("Als Extern markieren") { onSetExtern(); dismiss() }
                    Divider().padding(.leading)
                    actionRow("Gericht entfernen", isDestructive: true) { onClear(); dismiss() }
                }
            case .empty:
                Group {
                    actionRow("Rezept auswählen") { showingPicker = true }
                    Divider().padding(.leading)
                    actionRow("Abendbrot einplanen") { onSetBrotzeit(); dismiss() }
                    Divider().padding(.leading)
                    actionRow("Als Extern markieren") { onSetExtern(); dismiss() }
                }
            case .brotzeit:
                Group {
                    actionRow("Rezept auswählen") { showingPicker = true }
                    Divider().padding(.leading)
                    actionRow("Auf anderen Tag verschieben") { showingMove = true }
                    Divider().padding(.leading)
                    actionRow("Als Extern markieren") { onSetExtern(); dismiss() }
                    Divider().padding(.leading)
                    actionRow("Gericht entfernen", isDestructive: true) { onClear(); dismiss() }
                }
            case .extern:
                Group {
                    actionRow("Rezept auswählen") { showingPicker = true }
                    Divider().padding(.leading)
                    actionRow("Auf anderen Tag verschieben") { showingMove = true }
                    Divider().padding(.leading)
                    actionRow("Abendbrot einplanen") { onSetBrotzeit(); dismiss() }
                    Divider().padding(.leading)
                    actionRow("Gericht entfernen", isDestructive: true) { onClear(); dismiss() }
                }
            }
        }
    }

    private func actionRow(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(isDestructive ? .red : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
