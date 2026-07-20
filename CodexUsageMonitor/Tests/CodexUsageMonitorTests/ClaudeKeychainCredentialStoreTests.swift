import XCTest
@testable import CodexUsageMonitor

final class ClaudeKeychainCredentialStoreTests: XCTestCase {
    /// Shape verified against a real Keychain "Claude Code-credentials" item
    /// on 2026-07-20: expiresAt/refreshTokenExpiresAt are Unix milliseconds.
    private let realShapedFixture = """
    {"claudeAiOauth":{"accessToken":"fixture-access-token","refreshToken":"fixture-refresh-token","expiresAt":1784572234658,"refreshTokenExpiresAt":1787074021658,"scopes":["user:file_upload","user:inference","user:mcp_servers","user:profile","user:sessions:claude_code"],"subscriptionType":"pro","rateLimitTier":"default_claude_ai"}}
    """

    func testLoadCredentialParsesRealShapedFixture() throws {
        let fixture = realShapedFixture
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(fixture.utf8)) }
        )

        let credential = try store.loadCredential()

        XCTAssertEqual(credential.accessToken, "fixture-access-token")
        XCTAssertEqual(credential.refreshToken, "fixture-refresh-token")
        XCTAssertEqual(credential.expiresAt, Date(timeIntervalSince1970: 1_784_572_234_658 / 1000))
        XCTAssertEqual(credential.scopes, ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"])
        XCTAssertEqual(credential.subscriptionType, "pro")
    }

    func testLoadCredentialThrowsNotFoundWhenKeychainItemMissing() {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .failure(.notFound) })

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testLoadCredentialThrowsMalformedDataForInvalidJSON() {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .success(Data("not json".utf8)) })

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialThrowsMalformedDataWhenAccessTokenMissing() {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"refreshToken":"x"}}"#.utf8)) }
        )

        XCTAssertThrowsError(try store.loadCredential()) { error in
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialToleratesMissingOptionalFields() throws {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"accessToken":"only-token"}}"#.utf8)) }
        )

        let credential = try store.loadCredential()

        XCTAssertEqual(credential.accessToken, "only-token")
        XCTAssertNil(credential.refreshToken)
        XCTAssertNil(credential.expiresAt)
        XCTAssertEqual(credential.scopes, [])
        XCTAssertNil(credential.subscriptionType)
    }
}
