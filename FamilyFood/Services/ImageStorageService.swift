import Foundation
import UIKit

final class ImageStorageService {
    /// Production instance — `<Documents>/RecipeImages`.
    static let shared = ImageStorageService(directory: FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RecipeImages"))

    private let baseDirectory: URL

    /// Test/injection initializer — `directory` is any writable directory
    /// (same seam as `PlanStore`/`SharedImportInbox`).
    init(directory: URL) {
        baseDirectory = directory
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func imageURL(for recipeId: UUID) -> URL? {
        let url = fileURL(for: recipeId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // Copy a bundled resource image into Documents on first launch
    func copyFromBundle(_ bundleURL: URL, forRecipeId id: UUID) throws {
        let dest = fileURL(for: id)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        try FileManager.default.copyItem(at: bundleURL, to: dest)
    }

    // Download a remote image and write to Documents
    func downloadAndSave(from url: URL, forRecipeId id: UUID) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        try data.write(to: fileURL(for: id))
    }

    // Save UIImage (from camera or photo picker) to Documents
    func save(_ image: UIImage, forRecipeId id: UUID) throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try data.write(to: fileURL(for: id))
    }

    func deleteImage(for id: UUID) {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) } catch {
            Log.persistence.error("recipe image not deleted: \(error.localizedDescription)")
        }
    }

    private func fileURL(for id: UUID) -> URL {
        baseDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }
}
