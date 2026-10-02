import UIKit

/// Minimal, "dumb" share target: copies the shared payload into the App Group inbox
/// and dismisses immediately. All parsing/routing happens later in the main app.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handle() }
    }

    private func handle() async {
        guard let inbox = SharedImportInbox(),
              let provider = (extensionContext?.inputItems as? [NSExtensionItem])?
                .compactMap({ $0.attachments })
                .flatMap({ $0 })
                .first else {
            return complete()
        }
        do {
            try await ShareImportReceiver(inbox: inbox).receive(NSItemProviderAdapter(provider: provider))
        } catch {
            // Unsupported / failed payload — nothing stashed; just dismiss.
        }
        complete()
    }

    private func complete() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
