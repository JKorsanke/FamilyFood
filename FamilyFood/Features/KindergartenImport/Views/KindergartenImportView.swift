import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct KindergartenImportView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("userSettings") private var settings: UserSettings = UserSettings()
    // Read-only here: observed so the missing-key hint disappears once a key is entered in Settings.
    @AppStorage(AnthropicKeyStore.defaultsKey) private var apiKey = ""
    @StateObject private var viewModel = KindergartenImportViewModel()
    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingChildPicker = false
    @State private var showingPDFImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FFScreenHeader(title: "Kita-Import")
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            missingKeyHint
                        }
                        photoSection
                        if let image = viewModel.selectedImage {
                            imagePreview(image)
                            importButton
                        }
                        if viewModel.isProcessing {
                            loadingView
                        }
                        if let plan = viewModel.mealPlan {
                            resultView(plan)
                            if store.kitaPlans.contains(where: { $0.id == plan.id }) {
                                Label("Zum Wochenplan hinzugefügt (\(store.kitaPlans.count) \(store.kitaPlans.count == 1 ? "Plan" : "Pläne") aktiv)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                            }
                        }
                        if let error = viewModel.errorMessage {
                            errorView(error)
                        }
                        if !store.kitaPlans.isEmpty {
                            activePlansSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.s24)   // 24pt screen axle
                    .padding(.top, AppTheme.Spacing.s8)
                    .padding(.bottom, AppTheme.Spacing.s24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // FFScreenHeader replaces the large title
        }
        .onChange(of: viewModel.mealPlan) { _, plan in
            guard let plan else { return }
            guard !store.kitaPlans.contains(where: { $0.id == plan.id }) else { return }
            if settings.children.isEmpty {
                store.kitaPlans.append(plan)
            } else {
                showingChildPicker = true
            }
        }
        .sheet(isPresented: $showingChildPicker) {
            childPickerSheet
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(image: $viewModel.selectedImage)
        }
        .fileImporter(isPresented: $showingPDFImporter, allowedContentTypes: [.pdf]) { result in
            handlePDFSelection(result)
        }
        .onChange(of: photoPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.selectedImage = image
                }
            }
        }
    }

    private func handlePDFSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                viewModel.errorMessage = "PDF konnte nicht gelesen werden."
                return
            }
            Task { await viewModel.importMealPlan(pdfData: data) }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Active plans

    private var activePlansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktive Kita-Pläne")
                .font(.headline)
            ForEach(store.kitaPlans) { plan in
                HStack {
                    Image(systemName: "building.2")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        if let childId = plan.childId,
                           let child = settings.children.first(where: { $0.id == childId }) {
                            Text(child.name)
                                .font(.subheadline)
                        } else {
                            Text("Kita-Plan")
                                .font(.subheadline)
                        }
                        if let weekOf = plan.weekOf {
                            Text("Woche: \(weekOf)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        store.kitaPlans.removeAll { $0.id == plan.id }
                        viewModel.clearDetectedPlan(matching: plan.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    // MARK: - Child picker

    private var childPickerSheet: some View {
        NavigationStack {
            List {
                Section("Für welches Kind ist dieser Plan?") {
                    ForEach(settings.children) { child in
                        Button {
                            savePlan(childId: child.id)
                            showingChildPicker = false
                        } label: {
                            Text(child.name)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                Section {
                    Button("Ohne Zuweisung speichern") {
                        savePlan(childId: nil)
                        showingChildPicker = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Kind auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showingChildPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func savePlan(childId: UUID?) {
        guard var plan = viewModel.mealPlan else { return }
        guard !store.kitaPlans.contains(where: { $0.id == plan.id }) else { return }
        plan.childId = childId
        store.kitaPlans.append(plan)
    }

    /// Shown until a key is stored. The key itself is entered in Settings.
    private var missingKeyHint: some View {
        Label("Für den Import brauchst du einen Anthropic API-Schlüssel. Du kannst ihn in den Einstellungen hinterlegen.",
              systemImage: "key")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speiseplan importieren")
                .font(.headline)
            HStack(spacing: 12) {
                Button { showingCamera = true } label: {
                    Label("Kamera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Fotos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button { showingPDFImporter = true } label: {
                Label("PDF importieren", systemImage: "doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isProcessing)
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var importButton: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            Task { await viewModel.importMealPlan() }
        } label: {
            Label("Speiseplan importieren", systemImage: "arrow.down.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isProcessing)
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Wird verarbeitet…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultView(_ plan: KitaMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Erkannter Speiseplan")
                    .font(.headline)
                if let weekOf = plan.weekOf {
                    Spacer()
                    Text("Woche vom \(weekOf)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            ForEach(plan.days, id: \.name) { day in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name)
                            .fontWeight(.medium)
                        if let date = day.date {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 110, alignment: .leading)
                    Text(day.meal ?? "–")
                        .foregroundStyle(day.meal == nil ? .secondary : .primary)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
