import XCTest
@testable import FamilyFood

final class AnthropicKeyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func test_effectiveKey_is_the_entered_key() {
        defaults.set("sk-entered", forKey: AnthropicKeyStore.defaultsKey)
        XCTAssertEqual(AnthropicKeyStore(defaults: defaults).effectiveKey, "sk-entered")
    }

    func test_effectiveKey_trims_the_entered_key() {
        defaults.set("  sk-entered\n", forKey: AnthropicKeyStore.defaultsKey)
        XCTAssertEqual(AnthropicKeyStore(defaults: defaults).effectiveKey, "sk-entered")
    }

    func test_effectiveKey_is_empty_when_nothing_entered() {
        XCTAssertEqual(AnthropicKeyStore(defaults: defaults).effectiveKey, "")
    }

    func test_effectiveKey_is_empty_for_whitespace_only_entered_key() {
        defaults.set("   ", forKey: AnthropicKeyStore.defaultsKey)
        XCTAssertEqual(AnthropicKeyStore(defaults: defaults).effectiveKey, "")
    }

    func test_hasKey_false_when_nothing_entered() {
        XCTAssertFalse(AnthropicKeyStore(defaults: defaults).hasKey)
    }

    func test_hasKey_false_for_whitespace_only_entered_key() {
        defaults.set(" \n", forKey: AnthropicKeyStore.defaultsKey)
        XCTAssertFalse(AnthropicKeyStore(defaults: defaults).hasKey)
    }

    func test_hasKey_true_when_key_entered() {
        defaults.set("sk-entered", forKey: AnthropicKeyStore.defaultsKey)
        XCTAssertTrue(AnthropicKeyStore(defaults: defaults).hasKey)
    }

    /// The stored key name is persisted state on installed devices — it must not drift.
    func test_defaultsKey_is_stable() {
        XCTAssertEqual(AnthropicKeyStore.defaultsKey, "anthropicApiKey")
    }
}
