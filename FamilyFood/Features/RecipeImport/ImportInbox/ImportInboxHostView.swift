import SwiftUI

/// Invisible host attached to the app root. Presents the import flow whenever the
/// coordinator surfaces a shared item.
struct ImportInboxHostView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var coordinator: ImportInboxCoordinator

    var body: some View {
        Color.clear
            .sheet(item: $coordinator.currentItem) { item in
                ImportInboxFlow(item: item, coordinator: coordinator)
                    .environmentObject(store)
            }
    }
}

/// Drives parsing + review for a single shared item, reusing the existing import stack.
private struct ImportInboxFlow: View {
    let item: InboxItem
    @ObservedObject var coordinator: ImportInboxCoordinator

    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userSettings") private var settings: UserSettings = UserSettings()

    @StateObject private var urlViewModel = RecipeImportViewModel()
    @StateObject private var viewModel = ImportInboxViewModel()
    @State private var draft: RecipeDraft?
    @State private var pendingMealPlan: KitaMealPlan?
    @State private var navigateToReview = false
    @State private var didStartURLImport = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { coordinator.skip(item) }
                    }
                }
                .navigationDestination(isPresented: $navigateToReview) {
                    if let draft {
                        RecipeReviewView(draft: draft, onDone: { coordinator.finish(item) })
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch ImportRoute.initial(for: item) {
        case .recipeURL(let urlString):
            urlImportView(urlString)
        case .pdfChooser:
            pdfChooserView
        }
    }

    // MARK: - URL → recipe

    private func urlImportView(_ urlString: String) -> some View {
        VStack(spacing: 16) {
            if urlViewModel.isLoading {
                ProgressView("Rezept wird importiert…")
            } else if let error = urlViewModel.errorMessage {
                errorView(error)
            }
        }
        .padding()
        .task {
            guard !didStartURLImport else { return }
            didStartURLImport = true
            let service = RecipeDatabaseService(modelContext: modelContext)
            let savedDirectly = await urlViewModel.importFromURL(urlString, databaseService: service)
            if savedDirectly {
                coordinator.finish(item)
            } else if let parsed = urlViewModel.draft {
                draft = parsed
                navigateToReview = true
            }
        }
    }

    // MARK: - PDF → ask user

    @ViewBuilder
    private var pdfChooserView: some View {
        if let pendingMealPlan {
            childAssignmentView(pendingMealPlan)
        } else {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Wird analysiert…")
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else {
                    Text("Was möchtest du importieren?")
                        .font(.headline)
                    chooserButton(title: "Speiseplan", subtitle: "Kita-Wochenplan", icon: "calendar") {
                        Task {
                            guard let plan = await viewModel.mealPlan(fromPDFAt: item.payloadURL) else { return }
                            if settings.children.isEmpty {
                                assignMealPlan(plan, to: nil)   // no children configured — save unassigned
                            } else {
                                pendingMealPlan = plan           // ask which child to assign
                            }
                        }
                    }
                    chooserButton(title: "Rezept", subtitle: "Einzelnes Rezept", icon: "fork.knife") {
                        Task {
                            guard let parsed = await viewModel.recipeDraft(fromPDFAt: item.payloadURL) else { return }
                            draft = parsed
                            navigateToReview = true
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Child assignment (meal plan)

    private func childAssignmentView(_ plan: KitaMealPlan) -> some View {
        List {
            Section("Für welches Kind ist dieser Plan?") {
                ForEach(settings.children) { child in
                    Button {
                        assignMealPlan(plan, to: child.id)
                    } label: {
                        Text(child.name).foregroundStyle(.primary)
                    }
                }
            }
            Section {
                Button("Ohne Zuweisung speichern") {
                    assignMealPlan(plan, to: nil)
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Kind auswählen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func assignMealPlan(_ plan: KitaMealPlan, to childId: UUID?) {
        var assigned = plan
        assigned.childId = childId
        if !store.kitaPlans.contains(where: { $0.id == assigned.id }) {
            store.kitaPlans.append(assigned)
        }
        pendingMealPlan = nil
        coordinator.finish(item)
    }

    private func chooserButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 36).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).font(.title)
            Text(message).font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}
