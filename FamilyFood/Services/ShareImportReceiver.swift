import Foundation
import UniformTypeIdentifiers

/// Abstraction over `NSItemProvider` so the routing logic is testable without a real
/// system item provider.
protocol SharedItemProviding {
    func hasItem(conformingTo type: UTType) -> Bool
    func loadData(for type: UTType) async throws -> Data
    func loadURL() async throws -> URL
}

enum ShareImportError: Error { case unsupported }

/// Pure logic that turns a shared item into an inbox entry. PDFs are stashed as `.pdf`,
/// web URLs as `.url`; anything else is rejected so `ShareViewController` can cancel.
struct ShareImportReceiver {
    let inbox: SharedImportInbox

    func receive(_ provider: SharedItemProviding) async throws {
        if provider.hasItem(conformingTo: .pdf) {
            let data = try await provider.loadData(for: .pdf)
            try inbox.enqueue(payload: data, kind: .pdf, originalFilename: "shared.pdf", sourceURL: nil)
        } else if provider.hasItem(conformingTo: .url) {
            let url = try await provider.loadURL()
            try inbox.enqueue(payload: Data(url.absoluteString.utf8), kind: .url,
                              originalFilename: nil, sourceURL: url.absoluteString)
        } else {
            throw ShareImportError.unsupported
        }
    }
}

/// Real adapter over `NSItemProvider`.
struct NSItemProviderAdapter: SharedItemProviding {
    let provider: NSItemProvider

    func hasItem(conformingTo type: UTType) -> Bool {
        provider.hasItemConformingToTypeIdentifier(type.identifier)
    }

    func loadData(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? ShareImportError.unsupported)
                }
            }
        }
    }

    func loadURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, error in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let string = String(data: data, encoding: .utf8),
                          let url = URL(string: string) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? ShareImportError.unsupported)
                }
            }
        }
    }
}
