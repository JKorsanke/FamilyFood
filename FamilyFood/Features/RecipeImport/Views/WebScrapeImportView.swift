import SwiftUI

struct WebScrapeImportView: View {
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RecipeImportViewModel()
    @State private var urlText = ""
    @State private var showSuccess = false
    @State private var navigateToReview = false

    var body: some View {
        Form {
            Section {
                TextField("https://...", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Rezept-URL")
            } footer: {
                Text("Websites mit strukturierten Rezeptdaten (z.B. Chefkoch) werden direkt importiert. Andere Seiten werden per KI analysiert.")
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button {
                    Task { await importURL() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView().padding(.trailing, 8)
                            Text("Wird importiert…")
                        } else {
                            Text("Importieren")
                        }
                        Spacer()
                    }
                }
                .disabled(urlText.isEmpty || viewModel.isLoading)
            }
        }
        .navigationTitle("URL importieren")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rezept importiert!", isPresented: $showSuccess) {
            Button("OK") { onDone() }
        }
        .navigationDestination(isPresented: $navigateToReview) {
            if let draft = viewModel.draft {
                RecipeReviewView(draft: draft, onDone: onDone)
            }
        }
    }

    private func importURL() async {
        let service = RecipeDatabaseService(modelContext: modelContext)
        let savedDirectly = await viewModel.importFromURL(urlText, databaseService: service)
        if savedDirectly {
            showSuccess = true
        } else if viewModel.draft != nil {
            navigateToReview = true
        }
    }
}
