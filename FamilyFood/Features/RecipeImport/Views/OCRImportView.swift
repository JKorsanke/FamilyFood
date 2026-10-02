import SwiftUI
import PhotosUI

struct OCRImportView: View {
    let onDone: () -> Void

    @StateObject private var viewModel = RecipeImportViewModel()
    @State private var capturedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var navigateToReview = false

    var body: some View {
        VStack(spacing: 24) {
            // Preview or placeholder
            Group {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(maxHeight: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tertiary)
                                Text("Foto der Rezeptseite aufnehmen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }
            }
            .padding(.horizontal)

            // Capture options
            HStack(spacing: 16) {
                Button { showCamera = true } label: {
                    Label("Kamera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Fotos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Recognise button
            if capturedImage != nil {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await recognise() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().padding(.trailing, 6)
                            Text("Wird erkannt…")
                        } else {
                            Label("Rezept erkennen", systemImage: "wand.and.stars")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Aus Kochbuch scannen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                }
            }
        }
        .navigationDestination(isPresented: $navigateToReview) {
            if let draft = viewModel.draft {
                RecipeReviewView(draft: draft, onDone: onDone)
            }
        }
    }

    private func recognise() async {
        guard let image = capturedImage else { return }
        await viewModel.importFromOCR(image)
        if viewModel.draft != nil {
            navigateToReview = true
        }
    }
}
