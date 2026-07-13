import CryptoKit
import Foundation

enum CodexProtocolError: LocalizedError {
    case invalidResponse(String)
    case missingAccount
    case missingCodexLimit
    case missingWindows

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let detail): "Codex app-server returned an invalid response: \(detail)"
        case .missingAccount: "Codex app-server did not return an account identity."
        case .missingCodexLimit: "Codex app-server did not return the Codex rate-limit lane."
        case .missingWindows: "Codex app-server did not return both quota windows."
        }
    }
}

enum CodexProtocol {
    static func initializeRequest() -> [String: Any] {
        [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": ["name": "codex-usage-monitor", "version": "0.1.0"],
                "capabilities": ["experimentalApi": true],
            ],
        ]
    }

    static func initializedNotification() -> [String: Any] { ["method": "initialized", "params": [:]] }
    static func accountRequest() -> [String: Any] { ["id": 2, "method": "account/read", "params": ["refreshToken": false]] }
    static func rateLimitsRequest() -> [String: Any] { ["id": 3, "method": "account/rateLimits/read"] }
    static func usageRequest() -> [String: Any] { ["id": 4, "method": "account/usage/read"] }

    static func parseSample(responses: [Int: [String: Any]], collectedAt: Date) throws -> CodexQuotaSample {
        guard let accountResult = result(for: 2, in: responses),
              let account = accountResult["account"] as? [String: Any],
              let email = account["email"] as? String,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CodexProtocolError.missingAccount
        }
        guard let limitResult = result(for: 3, in: responses) else {
            throw CodexProtocolError.invalidResponse("missing rate-limit response")
        }
        let rateLimitsByID = limitResult["rateLimitsByLimitId"] as? [String: Any]
        let rateLimits = (rateLimitsByID?["codex"] as? [String: Any]) ?? (limitResult["rateLimits"] as? [String: Any])
        guard let rateLimits else { throw CodexProtocolError.missingCodexLimit }
        guard let limitID = rateLimits["limitId"] as? String, limitID == "codex" else {
            throw CodexProtocolError.missingCodexLimit
        }
        let primary = window(from: rateLimits["primary"])
        let secondary = window(from: rateLimits["secondary"])
        guard let weekly = weeklyWindow(primary: primary, secondary: secondary) else {
            throw CodexProtocolError.missingWindows
        }
        let fiveHour = shortTermWindow(primary: primary, secondary: secondary)

        let credits = rateLimits["credits"] as? [String: Any]
        let resetCredits = limitResult["rateLimitResetCredits"] as? [String: Any]
        let expiries = (resetCredits?["credits"] as? [[String: Any]] ?? []).compactMap {
            unixDate($0["expiresAt"])
        }.sorted()

        return CodexQuotaSample(
            accountFingerprint: fingerprint(for: email),
            limitID: limitID,
            planType: rateLimits["planType"] as? String,
            creditBalance: string(from: credits?["balance"]),
            hasCredits: credits?["hasCredits"] as? Bool,
            availableResetCredits: integer(from: resetCredits?["availableCount"]),
            resetCreditExpiryDates: expiries,
            fiveHour: fiveHour,
            weekly: weekly,
            collectedAt: collectedAt
        )
    }

    private static func result(for id: Int, in responses: [Int: [String: Any]]) -> [String: Any]? {
        responses[id]?["result"] as? [String: Any]
    }

    private static func window(from raw: Any?) -> QuotaWindow? {
        guard let values = raw as? [String: Any], let usedPercent = integer(from: values["usedPercent"]) else { return nil }
        return QuotaWindow(
            usedPercent: usedPercent,
            resetAt: unixDate(values["resetsAt"]),
            durationMinutes: integer(from: values["windowDurationMins"])
        )
    }

    private static func weeklyWindow(primary: QuotaWindow?, secondary: QuotaWindow?) -> QuotaWindow? {
        if primary?.durationMinutes == 10_080 { return primary }
        if secondary?.durationMinutes == 10_080 { return secondary }
        return secondary
    }

    private static func shortTermWindow(primary: QuotaWindow?, secondary: QuotaWindow?) -> QuotaWindow? {
        if primary?.durationMinutes == 10_080 { return secondary }
        if secondary?.durationMinutes == 10_080 { return primary }
        return primary
    }

    private static func unixDate(_ value: Any?) -> Date? {
        guard let timestamp = integer(from: value) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func integer(from value: Any?) -> Int? {
        if let value = value as? Int { return value }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.intValue
    }

    private static func string(from value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func fingerprint(for email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
