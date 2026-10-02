import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Bindable var recipe: RecipeModel
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage

                VStack(alignment: .leading, spacing: 16) {
                    // Badges
                    HStack(spacing: 8) {
                        dietBadge
                        if recipe.isFamilyFriendly { familyBadge }
                    }

                    // Summary
                    if let summary = recipe.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Times
                    if recipe.prepTime != nil || recipe.cookTime != nil || recipe.displayTotalTime != nil {
                        timesRow
                    }

                    // Servings
                    if let servings = recipe.servings {
                        Label("\(servings) \(recipe.servingsUnit ?? "Portionen")",
                              systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Ingredients
                    if !recipe.ingredientGroups.isEmpty {
                        ingredientsSection
                    }

                    // Source link
                    if let urlString = recipe.sourceURL, let url = URL(string: urlString) {
                        Link("Originalrezept öffnen", destination: url)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    RecipeDatabaseService(modelContext: modelContext).toggleFavourite(recipe)
                } label: {
                    Image(systemName: recipe.isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavourite ? .red : .primary)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Rezept löschen", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Rezept löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                let service = RecipeDatabaseService(modelContext: modelContext)
                do { try service.delete(recipe) } catch {
                    Log.persistence.error("recipe delete failed: \(error.localizedDescription)")
                }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: — Subviews

    @ViewBuilder
    private var heroImage: some View {
        RecipeImageView(recipeId: recipe.id)
            .frame(height: 220)
            .clipped()
    }

    private var dietBadge: some View {
        Label(recipe.dietStyle.displayName, systemImage: recipe.dietStyle.systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }

    private var familyBadge: some View {
        Label("Familienfreundlich", systemImage: "person.2.fill")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }

    private var timesRow: some View {
        HStack(spacing: 20) {
            if let prep = recipe.prepTime {
                timeCell(label: "Vorbereitung", minutes: prep)
            }
            if let cook = recipe.cookTime {
                timeCell(label: "Kochen", minutes: cook)
            }
            if let total = recipe.displayTotalTime {
                timeCell(label: "Gesamt", minutes: total)
            }
        }
    }

    private func timeCell(label: String, minutes: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(minutes) Min.")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zutaten")
                .font(.headline)

            ForEach(recipe.ingredientGroups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                if !group.name.isEmpty {
                    Text(group.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                ForEach(group.ingredients.sorted { $0.sortOrder < $1.sortOrder }) { ing in
                    HStack(alignment: .top, spacing: 8) {
                        Text([ing.amount, ing.unit].filter { !$0.isEmpty }.joined(separator: " "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(ing.name)
                                .font(.subheadline)
                            if !ing.notes.isEmpty {
                                Text(ing.notes)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
