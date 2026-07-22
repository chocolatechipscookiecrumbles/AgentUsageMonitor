import XCTest
@testable import CodexUsageMonitor

private final class TokenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Data?
    private var spawns = 0

    var data: Data? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    var spawnCount: Int {
        get { lock.withLock { spawns } }
        set { lock.withLock { spawns = newValue } }
    }

    func recordSpawn() { lock.withLock { spawns += 1 } }
}

final class ClaudeExecutableLocatorTests: XCTestCase {
    func testHonorsExplicitOverride() throws {
        let locator = ClaudeExecutableLocator(
            environment: ["CLAUDE_EXECUTABLE": "/custom/bin/claude"],
            isExecutable: { $0 == "/custom/bin/claude" }
        )

        XCTAssertEqual(try locator.locate().path, "/custom/bin/claude")
    }

    func testFindsExecutableOnPath() throws {
        let locator = ClaudeExecutableLocator(
            environment: ["PATH": "/nope:/opt/tools"],
            isExecutable: { $0 == "/opt/tools/claude" }
        )

        XCTAssertEqual(try locator.locate().path, "/opt/tools/claude")
    }

    /// The official `claude.ai/install.sh` installs to ~/.local/bin. A GUI
    /// .app does not inherit the login shell's PATH, so this location must be
    /// an explicit candidate rather than relying on a PATH scan.
    func testFindsOfficialInstallerLocationWithoutPath() throws {
        let expected = NSHomeDirectory() + "/.local/bin/claude"
        let locator = ClaudeExecutableLocator(
            environment: [:],
            isExecutable: { $0 == expected }
        )

        XCTAssertEqual(try locator.locate().path, expected)
    }

    func testThrowsMissingCLIWhenNothingExecutable() {
        let locator = ClaudeExecutableLocator(environment: [:], isExecutable: { _ in false })

        XCTAssertThrowsError(try locator.locate()) { error in
            XCTAssertEqual(error as? ClaudeSetupTokenError, .missingCLI)
        }
    }
}

private let fixtureToken = "sk-ant-oat01-fixture-token-value"

private func makeSnapshot(planHint: String?) -> ClaudeUsageSnapshot {
    ClaudeUsageSnapshot(
        planHint: planHint, fiveHour: nil, sevenDay: nil, scopedWindows: [], extraUsage: nil,
        source: .oauth, capturedAt: .now, schemaVersion: 1
    )
}

final class ClaudeSetupTokenServiceTests: XCTestCase {
    private func makeStore(box: TokenBox) -> ClaudeSelfIssuedCredentialStore {
        ClaudeSelfIssuedCredentialStore(
            rawDataReader: { box.data.map { .success($0) } ?? .failure(.notFound) },
            rawDataWriter: { data in box.data = data; return true },
            rawDeleter: { box.data = nil }
        )
    }

    func testEnvironmentTokenIsUsedWithoutSpawningProcess() async throws {
        let box = TokenBox()
        let service = ClaudeSetupTokenService(
            store: makeStore(box: box),
            environmentReader: { $0 == "CLAUDE_CODE_OAUTH_TOKEN" ? fixtureToken : nil },
            setupTokenRunner: { box.recordSpawn(); return "" },
            usageValidator: { _ in .success(makeSnapshot(planHint: "pro")) }
        )

        let account = try await service.connect()

        XCTAssertEqual(account.planType, "pro")
        XCTAssertEqual(box.spawnCount, 0, "env token must short-circuit the CLI spawn")
        XCTAssertNotNil(box.data, "credential should be persisted")
    }

    func testExtractsTokenFromNoisyCLIOutput() async throws {
        let box = TokenBox()
        let noisyOutput = """
        Opening browser for authentication...
        ✔ Authenticated as david@example.com

          \(fixtureToken)

        Store this token securely.
        """
        let service = ClaudeSetupTokenService(
            store: makeStore(box: box),
            environmentReader: { _ in nil },
            setupTokenRunner: { box.recordSpawn(); return noisyOutput },
            usageValidator: { credential in
                XCTAssertEqual(credential.accessToken, fixtureToken)
                return .success(makeSnapshot(planHint: "max"))
            }
        )

        let account = try await service.connect()

        XCTAssertEqual(account.planType, "max")
        XCTAssertEqual(box.spawnCount, 1)
    }

    func testThrowsWhenOutputContainsNoToken() async {
        let service = ClaudeSetupTokenService(
            store: makeStore(box: TokenBox()),
            environmentReader: { _ in nil },
            setupTokenRunner: { "authentication cancelled" },
            usageValidator: { _ in .success(makeSnapshot(planHint: nil)) }
        )

        await XCTAssertThrowsErrorAsync(try await service.connect()) { error in
            XCTAssertEqual(error as? ClaudeSetupTokenError, .tokenNotFoundInOutput)
        }
    }

    func testMissingCLISurfacesMissingCLIError() async {
        let service = ClaudeSetupTokenService(
            store: makeStore(box: TokenBox()),
            environmentReader: { _ in nil },
            setupTokenRunner: { throw ClaudeSetupTokenError.missingCLI },
            usageValidator: { _ in .success(makeSnapshot(planHint: nil)) }
        )

        await XCTAssertThrowsErrorAsync(try await service.connect()) { error in
            XCTAssertEqual(error as? ClaudeSetupTokenError, .missingCLI)
        }
    }

    func testPastedTokenIsAcceptedAndValidated() async throws {
        let box = TokenBox()
        let service = ClaudeSetupTokenService(
            store: makeStore(box: box),
            environmentReader: { _ in nil },
            setupTokenRunner: { box.recordSpawn(); return "" },
            usageValidator: { _ in .success(makeSnapshot(planHint: "pro")) }
        )

        let account = try await service.connect(pastedToken: "  \(fixtureToken)\n")

        XCTAssertEqual(account.planType, "pro")
        XCTAssertEqual(box.spawnCount, 0, "a pasted token must not spawn the CLI")
        XCTAssertNotNil(box.data)
    }

    func testRejectedTokenIsNotPersisted() async {
        let box = TokenBox()
        let service = ClaudeSetupTokenService(
            store: makeStore(box: box),
            environmentReader: { _ in fixtureToken },
            setupTokenRunner: { "" },
            usageValidator: { _ in .failure(.unauthorized) }
        )

        await XCTAssertThrowsErrorAsync(try await service.connect()) { error in
            XCTAssertEqual(error as? ClaudeSetupTokenError, .rejected)
        }
        XCTAssertNil(box.data, "a rejected token must never be persisted")
    }

    /// Secret hygiene: the long-lived token must never ride along inside an
    /// error that could be logged or shown.
    func testTokenNeverAppearsInThrownErrorDescription() async {
        let service = ClaudeSetupTokenService(
            store: makeStore(box: TokenBox()),
            environmentReader: { _ in fixtureToken },
            setupTokenRunner: { "" },
            usageValidator: { _ in .failure(.unauthorized) }
        )

        await XCTAssertThrowsErrorAsync(try await service.connect()) { error in
            XCTAssertFalse("\(error)".contains(fixtureToken))
            XCTAssertFalse(String(describing: error).contains(fixtureToken))
        }
    }

    func testExtractTokenIgnoresNonSetupTokens() {
        XCTAssertNil(ClaudeSetupTokenService.extractToken(from: "sk-ant-api03-not-a-setup-token"))
        XCTAssertNil(ClaudeSetupTokenService.extractToken(from: "no token here"))
        XCTAssertEqual(
            ClaudeSetupTokenService.extractToken(from: "token: \"sk-ant-oat01-abc\","),
            "sk-ant-oat01-abc"
        )
    }
}

/// XCTAssertThrowsError has no async form in this toolchain.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
