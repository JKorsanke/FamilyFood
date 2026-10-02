import SwiftUI

struct UserSettingsView: View {
    @AppStorage("userSettings") private var settings: UserSettings = UserSettings()
    @AppStorage(AnthropicKeyStore.defaultsKey) private var apiKey = ""
    @EnvironmentObject private var store: AppStore
    @State private var showingAddChild = false
    @State private var newChildName = ""
    @State private var editingChildID: UUID?
    @State private var editingChildName = ""
    @FocusState private var focusedChildID: UUID?
    @State private var showAllAllergens = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FFScreenHeader(title: "Einstellungen")
                Form {
                    dietSection
                    cookTimeSection
                    warmMealDaysSection
                    householdSection
                    childrenSection
                    allergenSection
                    apiKeySection
                }
                .contentMargins(.horizontal, AppTheme.Spacing.s24, for: .scrollContent)   // 24pt screen axle
            }
            // The Form is still system-styled; the header sits on the same system grouped grey so
            // the two read as one surface. No AppTheme token for it until Settings gets its
            // design pass.
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)   // FFScreenHeader replaces the large title
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if editingChildID != nil {
                        Button("Abbrechen") { cancelChildEdit() }
                        Spacer()
                        Button("Speichern") { commitChildEdit() }
                    }
                }
            }
            .onChange(of: focusedChildID) { _, newValue in
                // Keyboard dismissed (swipe) or focus moved away without Speichern → cancel.
                if newValue == nil && editingChildID != nil {
                    editingChildID = nil
                    editingChildName = ""
                }
            }
        }
        .sheet(isPresented: $showingAddChild) {
            addChildSheet
        }
    }

    // MARK: - Diet style

    private var dietSection: some View {
        Section("Ernährung") {
            Picker("Ernährungsweise", selection: $settings.dietStyle) {
                ForEach(DietStyle.manualCases, id: \.self) { style in
                    Label(style.displayName, systemImage: style.systemImage)
                        .tag(style)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Cook time

    private var cookTimeSection: some View {
        Section("Kochzeit limitieren") {
            Toggle("Zeitlimit", isOn: Binding(
                get: { settings.maxCookTimeMinutes != nil },
                set: { settings.maxCookTimeMinutes = $0 ? 30 : nil }
            ))

            if settings.maxCookTimeMinutes != nil {
                Stepper(
                    "Zubereitungszeit max. \(settings.maxCookTimeMinutes ?? 30) Min.",
                    value: Binding(
                        get: { settings.maxCookTimeMinutes ?? 30 },
                        set: { settings.maxCookTimeMinutes = $0 }
                    ),
                    in: 15...180,
                    step: 15
                )
            }
        }
    }

    // MARK: - Warm meal days

    private var warmMealDaysSection: some View {
        Section("Warme Mahlzeit(en)") {
            ForEach(Weekday.allCases) { weekday in
                Toggle(weekday.displayName, isOn: Binding(
                    get: { settings.warmMealDays.contains(weekday) },
                    set: { include in
                        if include {
                            settings.warmMealDays.insert(weekday)
                        } else {
                            settings.warmMealDays.remove(weekday)
                        }
                    }
                ))
            }
        }
    }

    // MARK: - Household

    private var householdSection: some View {
        Section("Haushalt") {
            Stepper("Erwachsene: \(settings.adults)", value: $settings.adults, in: 1...10)
        }
    }

    // MARK: - Children

    private var childrenSection: some View {
        Section("Kind(er)") {
            ForEach(settings.children) { child in
                childRow(child)
            }
            .onDelete { indices in
                settings.children.remove(atOffsets: indices)
            }
            Button("Kind hinzufügen") {
                newChildName = ""
                showingAddChild = true
            }
        }
    }

    /// A child entry: tap the pencil to edit the name inline (opens the keyboard, with
    /// Speichern/Abbrechen in the keyboard bar). `editingChildID` decides which row is editing;
    /// `focusedChildID` drives the actual keyboard focus.
    @ViewBuilder
    private func childRow(_ child: Child) -> some View {
        if editingChildID == child.id {
            TextField("Name", text: $editingChildName)
                .focused($focusedChildID, equals: child.id)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitChildEdit() }
        } else {
            HStack {
                Text(child.name)
                Spacer()
                Button {
                    beginChildEdit(child)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(child.name) umbenennen")
            }
        }
    }

    private func beginChildEdit(_ child: Child) {
        // Reaching for another child's pencil mid-edit commits the current row first, rather
        // than silently dropping the in-progress draft (the keyboard never passes through nil
        // on a row-to-row focus move, so onChange wouldn't catch it).
        if let id = editingChildID, id != child.id {
            settings.renameChild(id: id, to: editingChildName)
        }
        editingChildName = child.name
        editingChildID = child.id
        focusedChildID = child.id
    }

    /// Speichern — persist the trimmed name. An emptied name deletes the child
    /// (see `UserSettings.renameChild`).
    private func commitChildEdit() {
        if let id = editingChildID {
            settings.renameChild(id: id, to: editingChildName)
        }
        endChildEdit()
    }

    /// Abbrechen — discard the draft, leave the child unchanged.
    private func cancelChildEdit() {
        endChildEdit()
    }

    private func endChildEdit() {
        focusedChildID = nil
        editingChildID = nil
        editingChildName = ""
    }

    private var addChildSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newChildName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Kind hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showingAddChild = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let trimmed = newChildName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        settings.children.append(Child(name: trimmed))
                        showingAddChild = false
                    }
                    .disabled(newChildName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    // MARK: - Allergens

    private var allergenSection: some View {
        Section("Allergene ausschließen") {
            ForEach(Array(allAllergens.prefix(3)), id: \.self) { allergen in
                allergenToggle(allergen)
            }
            if showAllAllergens {
                ForEach(Array(allAllergens.dropFirst(3)), id: \.self) { allergen in
                    allergenToggle(allergen)
                }
            }
            Button(showAllAllergens ? "Weniger anzeigen" : "\(allAllergens.count - 3) weitere anzeigen") {
                showAllAllergens.toggle()
            }
            .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Anthropic API key

    /// The one place the key is entered. `AnthropicKeyStore` reads the same
    /// `UserDefaults` entry (and trims it) when a request is made.
    private var apiKeySection: some View {
        Section {
            SecureField("sk-ant-...", text: $apiKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("Anthropic API-Schlüssel")
        } footer: {
            Text("Nur für den Import von Kita-Speiseplänen und Rezepten nötig. Der Schlüssel wird auf diesem Gerät gespeichert und ausschließlich an die Anthropic-API gesendet.")
        }
    }

    private func allergenToggle(_ allergen: String) -> some View {
        Toggle(allergen, isOn: Binding(
            get: { settings.allergens.contains(allergen) },
            set: { include in
                if include {
                    if !settings.allergens.contains(allergen) {
                        settings.allergens.append(allergen)
                    }
                } else {
                    settings.allergens.removeAll { $0 == allergen }
                }
            }
        ))
    }
}
