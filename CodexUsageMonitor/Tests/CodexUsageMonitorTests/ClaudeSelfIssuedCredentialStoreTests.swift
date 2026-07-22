import XCTest
import Security
@testable import CodexUsageMonitor

/// Mutable in-memory stand-in for the Keychain so the suite never touches the
/// real one (same discipline as ClaudeKeychainCredentialStoreTests).
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Data?

    init(_ initial: Data? = nil) { stored = initial }

    var data: Data? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

final class ClaudeSelfIssuedCredentialStoreTests: XCTestCase {
    private func makeStore(box: DataBox) -> ClaudeSelfIssuedCredentialStore {
        ClaudeSelfIssuedCredentialStore(
            rawDataReader: { box.data.map { .success($0) } ?? .failure(.notFound) },
            rawDataWriter: { data in box.data = data; return true },
            rawDeleter: { box.data = nil }
        )
    }

    func testRoundTripsCredential() throws {
        let box = DataBox()
        let store = makeStore(box: box)
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let credential = ClaudeOAuthCredential(
            accessToken: "sk-ant-oat01-fixture",
            refreshToken: "refresh-fixture",
            expiresAt: expiry,
            scopes: ["user:profile", "user:inference"],
            subscriptionType: "pro"
        )

        try store.save(credential)
        let loaded = try store.loadCredential()

        XCTAssertEqual(loaded.accessToken, "sk-ant-oat01-fixture")
        XCTAssertEqual(loaded.refreshToken, "refresh-fixture")
        XCTAssertEqual(loaded.expiresAt, expiry)
        XCTAssertEqual(loaded.scopes, ["user:profile", "user:inference"])
        XCTAssertEqual(loaded.subscriptionType, "pro")
    }

    func testRoundTripsCredentialWithOnlyAccessToken() throws {
        let box = DataBox()
        let store = makeStore(box: box)
        let credential = ClaudeOAuthCredential(
            accessToken: "only-token", refreshToken: nil, expiresAt: nil, scopes: [], subscriptionType: nil
        )

        try store.save(credential)
        let loaded = try store.loadCredential()

        XCTAssertEqual(loaded.accessToken, "only-token")
        XCTAssertNil(loaded.refreshToken)
        XCTAssertNil(loaded.expiresAt)
        XCTAssertEqual(loaded.scopes, [])
        XCTAssertNil(loaded.subscriptionType)
    }

    func testLoadThrowsNotFoundWhenItemMissing() {
        let store = makeStore(box: DataBox())

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testLoadThrowsMalformedDataForCorruptItem() {
        let store = makeStore(box: DataBox(Data("not json".utf8)))

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testDeleteRemovesStoredCredential() throws {
        let box = DataBox()
        let store = makeStore(box: box)
        try store.save(
            ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: [], subscriptionType: nil)
        )
        XCTAssertNotNil(box.data)

        store.delete()

        XCTAssertNil(box.data)
        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testSaveThrowsAccessDeniedWhenWriteFails() {
        let store = ClaudeSelfIssuedCredentialStore(
            rawDataReader: { .failure(.notFound) },
            rawDataWriter: { _ in false },
            rawDeleter: {}
        )

        XCTAssertThrowsError(
            try store.save(
                ClaudeOAuthCredential(accessToken: "t", refreshToken: nil, expiresAt: nil, scopes: [], subscriptionType: nil)
            )
        ) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .accessDenied)
        }
    }

    /// The item we create must be device-only and never sync to iCloud.
    func testAddQueryIsDeviceOnlyAndNotSynchronizable() {
        let query = ClaudeSelfIssuedCredentialStore.addQuery(
            service: ClaudeSelfIssuedCredentialStore.defaultService,
            data: Data("x".utf8)
        )

        XCTAssertEqual(query[kSecAttrService as String] as? String, "AgentUsageMonitor-ClaudeOAuth")
        XCTAssertEqual(
            query[kSecAttrAccessible as String] as! CFString,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
        XCTAssertNil(query[kSecAttrSynchronizable as String], "the item must never be iCloud-synchronizable")
    }

    func testEnvironmentTokenTakesPrecedenceOverStoredItem() throws {
        let box = DataBox()
        let store = ClaudeSelfIssuedCredentialStore(
            rawDataReader: { box.data.map { .success($0) } ?? .failure(.notFound) },
            rawDataWriter: { data in box.data = data; return true },
            rawDeleter: { box.data = nil },
            environmentReader: { $0 == "CLAUDE_CODE_OAUTH_TOKEN" ? "sk-ant-oat01-from-env" : nil }
        )
        try store.save(
            ClaudeOAuthCredential(accessToken: "stored", refreshToken: nil, expiresAt: nil, scopes: [], subscriptionType: nil)
        )

        XCTAssertEqual(try store.loadCredential().accessToken, "sk-ant-oat01-from-env")
    }

    func testEnvironmentTokenIsUsedWhenNoItemStored() throws {
        let store = ClaudeSelfIssuedCredentialStore(
            rawDataReader: { .failure(.notFound) },
            rawDataWriter: { _ in true },
            rawDeleter: {},
            environmentReader: { _ in "  sk-ant-oat01-padded\n" }
        )

        let credential = try store.loadCredential()

        XCTAssertEqual(credential.accessToken, "sk-ant-oat01-padded", "whitespace must be trimmed")
        XCTAssertTrue(credential.scopes.contains("user:profile"), "must pass the usage source's scope guard")
    }

    func testEmptyEnvironmentTokenIsIgnored() {
        let store = ClaudeSelfIssuedCredentialStore(
            rawDataReader: { .failure(.notFound) },
            rawDataWriter: { _ in true },
            rawDeleter: {},
            environmentReader: { _ in "   " }
        )

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    /// The injected initializer must stay hermetic — a real environment
    /// variable on the test machine must never change a test's outcome.
    func testInjectedInitializerDoesNotReadTheRealEnvironment() {
        let store = ClaudeSelfIssuedCredentialStore(
            rawDataReader: { .failure(.notFound) },
            rawDataWriter: { _ in true },
            rawDeleter: {}
        )

        XCTAssertThrowsError(try store.loadCredential())
    }

    /// Guards the secret-hygiene rule: the token must not leak through the
    /// service name or any other non-data attribute.
    func testAddQueryDoesNotPlaceTokenOutsideValueData() {
        let token = "sk-ant-oat01-secret"
        let query = ClaudeSelfIssuedCredentialStore.addQuery(service: "svc", data: Data(token.utf8))

        for (key, value) in query where key != (kSecValueData as String) {
            XCTAssertFalse("\(value)".contains(token), "token leaked into \(key)")
        }
    }
}
