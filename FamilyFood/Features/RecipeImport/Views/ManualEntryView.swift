import SwiftUI

struct ManualEntryView: View {
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var summary = ""
    @State private var dietStyle = DietStyle.omnivore
    @State private var isFamilyFriendly = false
    @State private var mainIngredient: String? = nil
    @State private var prepTimeText = ""
    @State private var cookTimeText = ""
    @State private var servingsText = ""
    @State private var servingsUnit = "Portionen"
    @State private var ingredients: [RecipeIngredientDraft] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && dietStyle != .unknown
    }

    var body: some View {
        Form {
            Section("Rezept") {
                TextField("Titel*", text: $title)
                TextField("Kurzbeschreibung", text: $summary, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section("Ernährungsweise*") {
                Picker("Ernährungsweise", selection: $dietStyle) {
                    ForEach(DietStyle.manualCases, id: \.self) { style in
                        Label(style.displayName, systemImage: style.systemImage).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Familienfreundlich", isOn: $isFamilyFriendly)
                Picker("Hauptzutat", selection: $mainIngredient) {
                    Text("Unbekannt").tag(String?.none)
                    ForEach(MainIngredient.allCases, id: \.self) { ingredient in
                        Text(ingredient.displayName).tag(String?.some(ingredient.rawValue))
                    }
                }
            }

            Section("Portionen") {
                HStack {
                    TextField("Anzahl", text: $servingsText)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    TextField("Einheit", text: $servingsUnit)
                }
            }

            Section("Zeiten (Minuten)") {
                HStack {
                    Text("Vorbereitung")
                    Spacer()
                    TextField("Min.", text: $prepTimeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                HStack {
                    Text("Kochen")
                    Spacer()
                    TextField("Min.", text: $cookTimeText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

            Section("Zutaten") {
                ForEach(ingredients.indices, id: \.self) { i in
                    IngredientInputRow(ingredient: $ingredients[i])
                }
                .onDelete { ingredients.remove(atOffsets: $0) }

                Button("+ Zutat hinzufügen") {
                    ingredients.append(RecipeIngredientDraft(amount: "", unit: "", name: "", notes: ""))
                }
                .font(.subheadline)
            }

            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("Rezept eingeben")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { Task { await save() } }
                    .disabled(!isValid || isSaving)
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var draft = RecipeDraft()
        draft.title = title.trimmingCharacters(in: .whitespaces)
        draft.summary = summary.isEmpty ? nil : summary
        draft.dietStyle = dietStyle
        draft.isFamilyFriendly = isFamilyFriendly
        draft.mainIngredient = mainIngredient
        draft.servings = servingsText.isEmpty ? nil : servingsText
        draft.servingsUnit = servingsUnit.isEmpty ? nil : servingsUnit
        draft.prepTime = Int(prepTimeText)
        draft.cookTime = Int(cookTimeText)
        draft.source = .manual

        let validIngredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if !validIngredients.isEmpty {
            draft.ingredientGroups = [IngredientGroupDraft(name: "", ingredients: validIngredients)]
        }

        do {
            let service = RecipeDatabaseService(modelContext: modelContext)
            try await service.save(draft)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: — Ingredient input row

struct IngredientInputRow: View {
    @Binding var ingredient: RecipeIngredientDraft

    var body: some View {
        HStack(spacing: 8) {
            TextField("Menge", text: $ingredient.amount)
                .frame(width: 52)
                .multilineTextAlignment(.center)
            TextField("Einh.", text: $ingredient.unit)
                .frame(width: 48)
                .multilineTextAlignment(.center)
            TextField("Zutat", text: $ingredient.name)
        }
        .font(.subheadline)
    }
}
