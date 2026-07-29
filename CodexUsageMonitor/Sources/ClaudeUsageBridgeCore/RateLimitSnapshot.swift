import Foundation

/// One rate-limit window as written to the local snapshot. Mirrors the JSON the
/// app's `ClaudeRateLimitSnapshotReader` consumes: `usedPercentage` (Double) and
/// `resetsAt` (epoch seconds).
public struct RateLimitWindow: Equatable, Sendable {
    public let usedPercentage: Double
    public let resetsAt: Int

    public init(usedPercentage: Double, resetsAt: Int) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    var jsonObject: [String: Any] {
        ["usedPercentage": usedPercentage, "resetsAt": resetsAt]
    }
}

/// The snapshot the bridge writes for the app to read. Carries an explicit
/// `schemaVersion` so the reader can evolve independently.
public struct RateLimitSnapshot: Equatable, Sendable {
    public static let schemaVersion = 1

    public let capturedAt: Int
    public let fiveHour: RateLimitWindow?
    public let sevenDay: RateLimitWindow?

    public init(capturedAt: Int, fiveHour: RateLimitWindow?, sevenDay: RateLimitWindow?) {
        self.capturedAt = capturedAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    /// The exact object serialized to disk. Absent windows are omitted (not
    /// written as null), matching the previous Python bridge.
    public var jsonObject: [String: Any] {
        var result: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "capturedAt": capturedAt,
        ]
        if let fiveHour { result["fiveHour"] = fiveHour.jsonObject }
        if let sevenDay { result["sevenDay"] = sevenDay.jsonObject }
        return result
    }
}
