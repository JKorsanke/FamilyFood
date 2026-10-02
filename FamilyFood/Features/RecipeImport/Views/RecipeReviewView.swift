import SwiftUI

// Shown after OCR parsing or LLM web-scrape. User reviews and edits before saving.
struct RecipeReviewView: View {
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft: RecipeDraft
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(draft: RecipeDraft, onDone: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onDone = onDone
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Rezept") {
                TextField("Titel*", text: $draft.title)
                TextField("Kurzbeschreibung", text: Binding(
                    get: { draft.summary ?? "" },
                    set: { draft.summary = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            Section("Ernährungsweise") {
                Picker("Ernährungsweise", selection: $draft.dietStyle) {
                    ForEach(DietStyle.allCases, id: \.self) { style in
                        Label(style.displayName, systemImage: style.systemImage).tag(style)
                    }
                }
                Toggle("Familienfreundlich", isOn: $draft.isFamilyFriendly)
                Picker("Hauptzutat", selection: Binding(
                    get: { draft.mainIngredient },
                    set: { draft.mainIngredient = $0 }
                )) {
                    Text("Unbekannt").tag(String?.none)
                    ForEach(MainIngredient.allCases, id: \.self) { ingredient in
                        Text(ingredient.displayName).tag(String?.some(ingredient.rawValue))
                    }
                }
            }

            Section("Zeiten (Minuten)") {
                HStack {
                    Text("Vorbereitung")
                    Spacer()
                    TextField("Min.", text: Binding(
                        get: { draft.prepTime.map(String.init) ?? "" },
                        set: { draft.prepTime = Int($0) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                }
                HStack {
                    Text("Kochen")
                    Spacer()
                    TextField("Min.", text: Binding(
                        get: { draft.cookTime.map(String.init) ?? "" },
                        set: { draft.cookTime = Int($0) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                }
            }

            if !draft.ingredientGroups.isEmpty {
                Section("Erkannte Zutaten (nur Vorschau)") {
                    ForEach(draft.ingredientGroups.indices, id: \.self) { gi in
                        let group = draft.ingredientGroups[gi]
                        if !group.name.isEmpty {
                            Text(group.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(group.ingredients.indices, id: \.self) { ii in
                            let ing = group.ingredients[ii]
                            HStack(spacing: 8) {
                                Text([ing.amount, ing.unit].filter { !$0.isEmpty }.joined(separator: " "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                                Text(ing.name).font(.caption)
                            }
                        }
                    }
                }
            }

            if let urlString = draft.sourceURL {
                Section("Quelle") {
                    Text(urlString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.caption) }
            }
        }
        .navigationTitle("Rezept prüfen")
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
        do {
            let service = RecipeDatabaseService(modelContext: modelContext)
            try await service.save(draft)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
