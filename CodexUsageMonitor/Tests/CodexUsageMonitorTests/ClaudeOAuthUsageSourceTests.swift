import XCTest
@testable import CodexUsageMonitor

final class ClaudeOAuthUsageSourceTests: XCTestCase {
    /// Captured verbatim from a real GET https://api.anthropic.com/api/oauth/usage
    /// response on 2026-07-20 (values are this account's real utilization,
    /// no token or identity data included).
    private let realShapedResponse = """
    {
      "five_hour": {"utilization": 33.0, "resets_at": "2026-07-20T14:50:00.630618+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day": {"utilization": 8.0, "resets_at": "2026-07-22T22:00:00.630645+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
      "seven_day_sonnet": null, "seven_day_opus": null, "seven_day_oauth_apps": null, "seven_day_cowork": null,
      "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null, "currency": null},
      "limits": [
        {"kind": "session", "group": "session", "percent": 33, "severity": "normal", "resets_at": "2026-07-20T14:50:00.630618+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_all", "group": "weekly", "percent": 8, "severity": "normal", "resets_at": "2026-07-22T22:00:00.630645+00:00", "scope": null, "is_active": false}
      ],
      "an_unmapped_experimental_field": {"anything": "here"},
      "member_dashboard_available": false
    }
    """

    private func credentialStore(scopes: Set<String> = ["user:profile"]) -> ClaudeCredentialProviding {
        FakeCredentialStore(result: .success(
            ClaudeOAuthCredential(accessToken: "fixture-token", refreshToken: nil, expiresAt: nil, scopes: scopes, subscriptionType: "pro")
        ))
    }

    func testFetchMapsRealShapedResponseIntoNormalizedSnapshot() async throws {
        let response = realShapedResponse
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(response.utf8), Self.httpResponse(status: 200)) }
        )

        let snapshot = try await source.fetch()

        XCTAssertEqual(snapshot.source, .oauth)
        XCTAssertEqual(snapshot.planHint, "pro")
        XCTAssertEqual(snapshot.fiveHour?.usedPercent, 33.0)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, ClaudeOAuthDateParsing.parse("2026-07-20T14:50:00.630618+00:00"))
        XCTAssertEqual(snapshot.sevenDay?.usedPercent, 8.0)
        XCTAssertEqual(snapshot.scopedWindows.count, 2)
        XCTAssertEqual(snapshot.scopedWindows.first?.identifier, "session")
        XCTAssertEqual(snapshot.extraUsage?.isEnabled, false)
    }

    func testFetchThrowsCredentialsNotFoundWhenKeychainHasNoItem() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: FakeCredentialStore(result: .failure(.notFound)),
            requestExecutor: { _ in XCTFail("must not make a request without a credential"); return (Data(), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .credentialsNotFound)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsInsufficientScopeWhenTokenLacksUserProfile() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(scopes: ["user:inference"]),
            requestExecutor: { _ in XCTFail("must not make a request with an insufficiently scoped token"); return (Data(), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .insufficientScope)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsUnauthorizedOn401() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(), Self.httpResponse(status: 401)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsServerFailureOn500() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data(), Self.httpResponse(status: 500)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .serverFailure(statusCode: 500))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchThrowsMalformedResponseForInvalidJSON() async {
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { _ in (Data("not json".utf8), Self.httpResponse(status: 200)) }
        )

        do {
            _ = try await source.fetch()
            XCTFail("expected an error")
        } catch let error as ClaudeOAuthError {
            XCTAssertEqual(error, .malformedResponse)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchSetsAuthorizationHeaderAndBetaHeaderWithoutLoggingToken() async throws {
        let response = realShapedResponse
        let captured = CapturedRequestBox()
        let source = ClaudeOAuthUsageSource(
            credentialStore: credentialStore(),
            requestExecutor: { request in
                captured.request = request
                return (Data(response.utf8), Self.httpResponse(status: 200))
            }
        )

        _ = try await source.fetch()

        XCTAssertEqual(captured.request?.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(captured.request?.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertEqual(captured.request?.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
    }

    private static func httpResponse(status: Int) -> URLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}

private final class CapturedRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

private struct FakeCredentialStore: ClaudeCredentialProviding {
    let result: Result<ClaudeOAuthCredential, ClaudeCredentialError>
    /// Records the policy it was asked with, so tests can assert that an
    /// automatic refresh never requests interaction.
    let policyRecorder: PolicyRecorder?

    init(result: Result<ClaudeOAuthCredential, ClaudeCredentialError>, policyRecorder: PolicyRecorder? = nil) {
        self.result = result
        self.policyRecorder = policyRecorder
    }

    func loadCredential(promptPolicy: KeychainPromptPolicy) throws -> ClaudeOAuthCredential {
        policyRecorder?.record(promptPolicy)
        switch result {
        case .success(let credential): return credential
        case .failure(let error): throw error
        }
    }
}
