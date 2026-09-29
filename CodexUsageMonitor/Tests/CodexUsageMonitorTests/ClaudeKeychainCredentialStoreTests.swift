import XCTest
import Security
import LocalAuthentication
@testable import CodexUsageMonitor

final class ClaudeKeychainPromptPolicyTests: XCTestCase {
    /// The whole point: a scheduled/menu-open refresh must be structurally
    /// incapable of raising the Keychain dialog.
    func testBackgroundPolicyForbidsInteraction() {
        let query = ClaudeKeychainCredentialStore.searchQuery(
            serviceName: "Claude Code-credentials", promptPolicy: .never
        )

        XCTAssertEqual(
            (query[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed,
            true
        )
    }

    func testLegacySilentReadDisablesInteractionAndRestoresPriorFlagOnFailure() {
        for initiallyAllowed in [false, true] {
            var allowed = initiallyAllowed
            var writes: [Bool] = []
            let result = ClaudeKeychainCredentialStore.withLegacyInteractionPolicy(
                .never,
                getAllowed: { $0.pointee = DarwinBoolean(allowed); return errSecSuccess },
                setAllowed: { allowed = $0; writes.append($0); return errSecSuccess },
                read: {
                    XCTAssertFalse(allowed, "legacy lookup must run with interaction disabled")
                    return .failure(.interactionNotAllowed)
                }
            )
            XCTAssertEqual(result, .failure(.interactionNotAllowed))
            XCTAssertEqual(writes, [false, initiallyAllowed])
            XCTAssertEqual(allowed, initiallyAllowed)
        }
    }

    func testLegacyFlagFailurePreventsReadAndRestorationFailureIsReported() {
        var readCount = 0
        var setCount = 0
        let result = ClaudeKeychainCredentialStore.withLegacyInteractionPolicy(
            .never,
            getAllowed: { $0.pointee = true; return errSecSuccess },
            setAllowed: { _ in
                setCount += 1
                return setCount == 1 ? errSecNotAvailable : errSecAuthFailed
            },
            read: { readCount += 1; return .success(Data()) }
        )
        XCTAssertEqual(readCount, 0)
        XCTAssertEqual(setCount, 2)
        XCTAssertEqual(result, .failure(.unexpectedStatus(errSecAuthFailed)))
    }

    func testUserInitiatedPolicyAllowsInteraction() {
        let query = ClaudeKeychainCredentialStore.searchQuery(
            serviceName: "Claude Code-credentials", promptPolicy: .userInitiatedOnly
        )

        XCTAssertNil(
            query[kSecUseAuthenticationContext as String],
            "a user-initiated read must be allowed to prompt"
        )
    }

    /// A denied read must degrade, never hard-fail: the collector needs to
    /// fall through to the next tier rather than surface an error.
    func testInteractionNotAllowedRemainsDistinctFromAccessDenied() {
        XCTAssertEqual(ClaudeKeychainCredentialStore.error(for: errSecInteractionNotAllowed), .interactionNotAllowed)
    }

    func testMissingItemMapsToNotFound() {
        XCTAssertEqual(ClaudeKeychainCredentialStore.error(for: errSecItemNotFound), .notFound)
    }

    func testOtherFailuresMapToAccessDenied() {
        XCTAssertEqual(ClaudeKeychainCredentialStore.error(for: errSecAuthFailed), .accessDenied)
    }

    /// Default resolution must be the safe one — a caller that forgets to pass
    /// a policy must not be able to trigger a prompt.
    func testDefaultPolicyIsNever() {
        XCTAssertEqual(ClaudeRefreshReason.scheduled.keychainPromptPolicy, .never)
        XCTAssertEqual(ClaudeRefreshReason.appLaunch.keychainPromptPolicy, .never)
        XCTAssertEqual(ClaudeRefreshReason.menuOpened.keychainPromptPolicy, .never)
        XCTAssertEqual(ClaudeRefreshReason.userInitiated.keychainPromptPolicy, .never)
    }
}

final class ClaudeKeychainCredentialStoreTests: XCTestCase {
    /// Shape verified against a real Keychain "Claude Code-credentials" item
    /// on 2026-07-20: expiresAt/refreshTokenExpiresAt are Unix milliseconds.
    private let realShapedFixture = """
    {"claudeAiOauth":{"accessToken":"fixture-access-token","refreshToken":"fixture-refresh-token","expiresAt":1784572234658,"refreshTokenExpiresAt":1787074021658,"scopes":["user:file_upload","user:inference","user:mcp_servers","user:profile","user:sessions:claude_code"],"subscriptionType":"pro","rateLimitTier":"default_claude_ai"}}
    """

    func testLoadCredentialParsesRealShapedFixture() async throws {
        let fixture = realShapedFixture
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(fixture.utf8)) }
        )

        let credential = try await store.loadCredential()

        XCTAssertEqual(credential.accessToken, "fixture-access-token")
        XCTAssertEqual(credential.scopes, ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"])
        XCTAssertEqual(credential.subscriptionType, "pro")
    }

    func testLoadCredentialThrowsNotFoundWhenKeychainItemMissing() async {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .failure(.notFound) })

        do {
            _ = try await store.loadCredential()
            XCTFail("expected credential failure")
        } catch {
            XCTAssertEqual(error as? ClaudeCredentialError, .notFound)
        }
    }

    func testLoadCredentialThrowsMalformedDataForInvalidJSON() async {
        let store = ClaudeKeychainCredentialStore(rawDataReader: { .success(Data("not json".utf8)) })

        do {
            _ = try await store.loadCredential()
            XCTFail("expected credential failure")
        } catch {
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialThrowsMalformedDataWhenAccessTokenMissing() async {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"refreshToken":"x"}}"#.utf8)) }
        )

        do {
            _ = try await store.loadCredential()
            XCTFail("expected credential failure")
        } catch {
            XCTAssertEqual(error as? ClaudeCredentialError, .malformedData)
        }
    }

    func testLoadCredentialToleratesMissingOptionalFields() async throws {
        let store = ClaudeKeychainCredentialStore(
            rawDataReader: { .success(Data(#"{"claudeAiOauth":{"accessToken":"only-token"}}"#.utf8)) }
        )

        let credential = try await store.loadCredential()

        XCTAssertEqual(credential.accessToken, "only-token")
        XCTAssertEqual(credential.scopes, [])
        XCTAssertNil(credential.subscriptionType)
    }
}
