import Foundation

struct ClaudeRateLimitWindow: Codable, Equatable {
    let usedPercentage: Double
    let resetsAt: Date

    private enum CodingKeys: String, CodingKey {
        case usedPercentage
        case resetsAt
    }

    init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercentage = try container.decode(Double.self, forKey: .usedPercentage)
        let resetsAtEpochSeconds = try container.decode(Double.self, forKey: .resetsAt)
        resetsAt = Date(timeIntervalSince1970: resetsAtEpochSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usedPercentage, forKey: .usedPercentage)
        try container.encode(resetsAt.timeIntervalSince1970, forKey: .resetsAt)
    }
}

struct ClaudeRateLimitSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let capturedAt: Date
    let fiveHour: ClaudeRateLimitWindow?
    let sevenDay: ClaudeRateLimitWindow?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case capturedAt
        case fiveHour
        case sevenDay
    }

    init(schemaVersion: Int, capturedAt: Date, fiveHour: ClaudeRateLimitWindow?, sevenDay: ClaudeRateLimitWindow?) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let capturedAtEpochSeconds = try container.decode(Double.self, forKey: .capturedAt)
        capturedAt = Date(timeIntervalSince1970: capturedAtEpochSeconds)
        fiveHour = try container.decodeIfPresent(ClaudeRateLimitWindow.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(ClaudeRateLimitWindow.self, forKey: .sevenDay)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(capturedAt.timeIntervalSince1970, forKey: .capturedAt)
        try container.encodeIfPresent(fiveHour, forKey: .fiveHour)
        try container.encodeIfPresent(sevenDay, forKey: .sevenDay)
    }
}
