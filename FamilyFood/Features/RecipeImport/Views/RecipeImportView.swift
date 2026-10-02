import SwiftUI

struct RecipeImportView: View {
    @Binding var isPresented: Bool
    @State private var showWebScrape = false
    @State private var showOCR = false
    @State private var showManual = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    importRow(
                        title: "URL importieren",
                        subtitle: "Rezept von einer Website laden",
                        icon: "link",
                        action: { showWebScrape = true }
                    )
                    importRow(
                        title: "Aus Kochbuch scannen",
                        subtitle: "Foto einer Rezeptseite aufnehmen",
                        icon: "camera.viewfinder",
                        action: { showOCR = true }
                    )
                    importRow(
                        title: "Manuell eingeben",
                        subtitle: "Rezept selbst eintragen",
                        icon: "square.and.pencil",
                        action: { showManual = true }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Rezept hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { isPresented = false }
                }
            }
            .navigationDestination(isPresented: $showWebScrape) {
                WebScrapeImportView(onDone: { isPresented = false })
            }
            .navigationDestination(isPresented: $showOCR) {
                OCRImportView(onDone: { isPresented = false })
            }
            .navigationDestination(isPresented: $showManual) {
                ManualEntryView(onDone: { isPresented = false })
            }
        }
    }

    private func importRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
