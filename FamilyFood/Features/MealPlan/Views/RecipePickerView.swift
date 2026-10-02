import SwiftUI

struct RecipePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    let recipes: [RecipeModel]
    let onSelect: (RecipeModel) -> Void

    private var filtered: [RecipeModel] {
        guard !searchText.isEmpty else { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { recipe in
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
            .searchable(text: $searchText, prompt: "Rezepte suchen")
            .navigationTitle("Rezept auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
