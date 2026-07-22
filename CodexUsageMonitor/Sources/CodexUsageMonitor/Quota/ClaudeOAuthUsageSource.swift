import Foundation

enum ClaudeOAuthError: Error, Equatable {
    case credentialsNotFound
    case insufficientScope
    case unauthorized
    case malformedResponse
    case serverFailure(statusCode: Int)
    case transportError
}

/// Parses the ISO 8601 timestamps this endpoint returns, including
/// microsecond-precision fractional seconds (verified against a real
/// response on 2026-07-20; ISO8601DateFormatter with .withFractionalSeconds
/// handles this format directly on this toolchain).
enum ClaudeOAuthDateParsing {
    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? withoutFractionalSeconds.date(from: string)
    }

    // ISO8601DateFormatter isn't Sendable, but these instances are only ever
    // read from after configuration (parsing is thread-safe in practice);
    // nonisolated(unsafe) opts out of the compiler's conservative check.
    private nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// Raw response shape for GET /api/oauth/usage. Kept private to this file —
/// only the normalized ClaudeUsageSnapshot is exposed to callers. Optional
/// everywhere except what's structurally guaranteed, and only the fields
/// this app actually uses are declared; unmapped/experimental fields the
/// endpoint also returns are silently ignored by Decodable.
private struct OAuthUsageResponse: Decodable {
    struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct Limit: Decodable {
        let kind: String
        let percent: Double
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case percent
            case resetsAt = "resets_at"
        }
    }

    struct ExtraUsage: Decodable {
        let isEnabled: Bool
        let monthlyLimit: Double?
        let usedCredits: Double?
        let currency: String?

        enum CodingKeys: String, CodingKey {
            case isEnabled = "is_enabled"
            case monthlyLimit = "monthly_limit"
            case usedCredits = "used_credits"
            case currency
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let extraUsage: ExtraUsage?
    let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case extraUsage = "extra_usage"
        case limits
    }
}

struct ClaudeOAuthUsageSource {
    private let credentialStore: ClaudeCredentialProviding
    private let requestExecutor: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        credentialStore: ClaudeCredentialProviding,
        requestExecutor: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession(configuration: .ephemeral).data(for: request)
        }
    ) {
        self.credentialStore = credentialStore
        self.requestExecutor = requestExecutor
    }

    /// `promptPolicy` defaults to the safe value: a caller that does not think
    /// about it cannot introduce a background Keychain prompt.
    func fetch(promptPolicy: KeychainPromptPolicy = .never) async throws -> ClaudeUsageSnapshot {
        let credential: ClaudeOAuthCredential
        do {
            credential = try credentialStore.loadCredential(promptPolicy: promptPolicy)
        } catch {
            throw ClaudeOAuthError.credentialsNotFound
        }
        guard credential.scopes.contains("user:profile") else {
            throw ClaudeOAuthError.insufficientScope
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await requestExecutor(request)
        } catch {
            throw ClaudeOAuthError.transportError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeOAuthError.malformedResponse
        }
        guard httpResponse.statusCode != 401, httpResponse.statusCode != 403 else {
            throw ClaudeOAuthError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw ClaudeOAuthError.serverFailure(statusCode: httpResponse.statusCode)
        }

        guard let parsed = try? JSONDecoder().decode(OAuthUsageResponse.self, from: data) else {
            throw ClaudeOAuthError.malformedResponse
        }

        return ClaudeUsageSnapshot(
            planHint: credential.subscriptionType,
            fiveHour: Self.window(parsed.fiveHour),
            sevenDay: Self.window(parsed.sevenDay),
            scopedWindows: (parsed.limits ?? []).map {
                ClaudeScopedLimitWindow(
                    identifier: $0.kind,
                    displayName: $0.kind,
                    usedPercent: $0.percent,
                    resetsAt: $0.resetsAt.flatMap(ClaudeOAuthDateParsing.parse)
                )
            },
            extraUsage: parsed.extraUsage.map {
                ClaudeExtraUsage(isEnabled: $0.isEnabled, monthlyLimit: $0.monthlyLimit, usedCredits: $0.usedCredits, currencyCode: $0.currency)
            },
            source: .oauth,
            capturedAt: .now,
            schemaVersion: 1
        )
    }

    private static func window(_ raw: OAuthUsageResponse.Window?) -> ClaudeLimitWindow? {
        guard let raw, let utilization = raw.utilization else { return nil }
        return ClaudeLimitWindow(usedPercent: utilization, resetsAt: raw.resetsAt.flatMap(ClaudeOAuthDateParsing.parse))
    }
}
