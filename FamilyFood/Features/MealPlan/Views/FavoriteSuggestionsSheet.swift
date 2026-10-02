import SwiftUI

struct FavoriteSuggestionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestions: [RecipeModel]
    let onSelect: (RecipeModel) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    ContentUnavailableView(
                        "Keine Favoriten",
                        systemImage: "star",
                        description: Text("Markiere zuerst Rezepte in der Rezeptdatenbank als Favoriten.")
                    )
                } else {
                    List(suggestions) { recipe in
                        Button {
                            onSelect(recipe)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.title)
                                    .foregroundStyle(.primary)
                                if let time = recipe.displayTotalTime {
                                    Text("\(time) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Vorschläge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
