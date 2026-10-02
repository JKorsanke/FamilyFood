import SwiftUI

/// Initial routing decision for a shared item.
enum ImportRoute: Equatable {
    case recipeURL(String)   // shared web/social URL → recipe import
    case pdfChooser          // shared PDF → ask the user: Speiseplan vs Rezept

    static func initial(for item: InboxItem) -> ImportRoute {
        switch item.descriptor.kind {
        case .url: return .recipeURL(item.descriptor.sourceURL ?? "")
        case .pdf: return .pdfChooser
        }
    }
}

/// Drains the shared inbox and publishes the item currently being imported. Items stay
/// queued until explicitly `finish`ed (imported) so a failed/abandoned import isn't lost.
@MainActor
final class ImportInboxCoordinator: ObservableObject {
    @Published var currentItem: InboxItem?
    private let inbox: SharedImportInbox?
    /// Dismissed-this-session items: kept out of `drain()` so "Schließen" doesn't
    /// re-present them, but left in the inbox to resurface on the next launch.
    private var skippedIDs: Set<UUID> = []

    init(inbox: SharedImportInbox? = SharedImportInbox()) { self.inbox = inbox }

    /// Present the next pending item, if any and none is currently shown.
    func drain() {
        guard currentItem == nil,
              let next = inbox?.pending().first(where: { !skippedIDs.contains($0.id) }) else { return }
        currentItem = next
    }

    /// Import completed — remove from inbox and advance to the next item.
    func finish(_ item: InboxItem) {
        inbox?.remove(item)
        currentItem = nil
        drain()
    }

    /// Dismissed without importing — leave it queued for a later retry.
    func skip(_ item: InboxItem) {
        skippedIDs.insert(item.id)
        currentItem = nil
        drain()
    }
}
