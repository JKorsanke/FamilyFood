import Foundation

/// Content type stashed in the shared inbox by the Share Extension.
enum InboxKind: String, Codable { case pdf, url }

/// Metadata describing a single shared payload waiting to be imported.
struct InboxDescriptor: Codable, Equatable {
    let id: UUID
    let kind: InboxKind
    let payloadFilename: String
    let originalFilename: String?
    let sourceURL: String?
    let receivedAt: Date
}

/// A pending inbox entry: its descriptor plus the on-disk payload location.
struct InboxItem: Identifiable, Equatable {
    let descriptor: InboxDescriptor
    let payloadURL: URL
    var id: UUID { descriptor.id }
}

/// File-based handoff between the Share Extension and the main app, living in the
/// App Group container. The extension `enqueue`s payloads; the app `pending()`s and
/// `remove()`s them once imported. Used only for raw file transfer — SwiftData and
/// in-memory Kita storage are untouched.
struct SharedImportInbox {
    /// Info.plist key carrying the App Group id. The value comes from the `FF_APP_GROUP`
    /// build setting (Config/Signing.xcconfig), the same setting the entitlements use.
    static let appGroupInfoKey = "FFAppGroupID"
    let inboxURL: URL

    /// The App Group id declared by a bundle's Info.plist, or nil when absent or blank.
    static func appGroupID(in infoDictionary: [String: Any]?) -> String? {
        guard let id = (infoDictionary?[appGroupInfoKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return nil }
        return id
    }

    /// Test/injection initializer — `baseURL` is any writable directory.
    init(baseURL: URL) {
        inboxURL = baseURL.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }

    /// Production initializer — resolves the shared App Group container.
    init?() {
        guard let groupID = Self.appGroupID(in: Bundle.main.infoDictionary),
              let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        self.init(baseURL: container)
    }

    @discardableResult
    func enqueue(payload: Data, kind: InboxKind, originalFilename: String?, sourceURL: String?) throws -> InboxDescriptor {
        let id = UUID()
        let payloadName = "\(id.uuidString).\(kind.rawValue)"
        let descriptor = InboxDescriptor(
            id: id, kind: kind, payloadFilename: payloadName,
            originalFilename: originalFilename, sourceURL: sourceURL, receivedAt: Date()
        )
        try payload.write(to: inboxURL.appendingPathComponent(payloadName))
        let json = try JSONEncoder().encode(descriptor)
        try json.write(to: inboxURL.appendingPathComponent("\(id.uuidString).json"))
        return descriptor
    }

    /// Pending items, oldest first.
    func pending() -> [InboxItem] {
        let files = (try? FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { jsonURL -> InboxItem? in
                guard let data = try? Data(contentsOf: jsonURL),
                      let descriptor = try? JSONDecoder().decode(InboxDescriptor.self, from: data) else {
                    Log.importing.error("inbox descriptor \(jsonURL.lastPathComponent) unreadable — shared item skipped")
                    return nil
                }
                return InboxItem(descriptor: descriptor,
                                 payloadURL: inboxURL.appendingPathComponent(descriptor.payloadFilename))
            }
            .sorted { $0.descriptor.receivedAt < $1.descriptor.receivedAt }
    }

    func remove(_ item: InboxItem) {
        do { try FileManager.default.removeItem(at: item.payloadURL) } catch {
            Log.importing.error("inbox payload \(item.descriptor.payloadFilename) not removed: \(error.localizedDescription)")
        }
        let jsonURL = inboxURL.appendingPathComponent("\(item.descriptor.id.uuidString).json")
        do { try FileManager.default.removeItem(at: jsonURL) } catch {
            Log.importing.error("inbox descriptor \(item.descriptor.id) not removed — item will re-surface: \(error.localizedDescription)")
        }
    }
}
