import Foundation

/// Single source of truth for the Anthropic API key used by all LLM-backed import
/// (Kita meal plan + recipe import). The user enters the key in Settings, which
/// writes it to `UserDefaults` via `@AppStorage(defaultsKey)`; there is no bundled
/// fallback. `defaults` is injectable so the resolution logic is unit-testable.
struct AnthropicKeyStore {
    var defaults: UserDefaults = .standard

    /// `UserDefaults` name of the stored key — the name the Settings field writes to.
    static let defaultsKey = "anthropicApiKey"

    /// The stored key, trimmed — what requests are sent with ("" when none).
    var effectiveKey: String {
        (defaults.string(forKey: Self.defaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when a usable key is stored.
    var hasKey: Bool {
        !effectiveKey.isEmpty
    }
}
