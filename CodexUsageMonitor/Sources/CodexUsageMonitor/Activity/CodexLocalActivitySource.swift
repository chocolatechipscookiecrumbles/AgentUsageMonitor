import CryptoKit
import Foundation

struct CodexLocalActivitySource: LocalActivitySource {
    let provider: AgentProvider = .codex

    private let sessionsRoot: URL
    private let reader = LocalActivityJSONLReader()

    init(
        sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    ) {
        self.sessionsRoot = sessionsRoot
    }

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        let files: [URL]
        do {
            files = try regularJSONLFiles()
        } catch {
            return LocalActivityScanResult(requests: [], cursors: [], status: .unsafeToRead)
        }
        guard !files.isEmpty else {
            return LocalActivityScanResult(requests: [], cursors: [], status: .localRecordsMissing)
        }

        var parsedFiles: [ParsedFile] = []
        do {
            for fileURL in files {
                let opaqueFileID = Self.digest(fileURL.standardizedFileURL.path)
                let result = try await reader.read(fileURL: fileURL)
                parsedFiles.append(parse(result: result, opaqueFileID: opaqueFileID))
            }
        } catch {
            return LocalActivityScanResult(requests: [], cursors: [], status: .unsafeToRead)
        }

        let priorOffsets = Dictionary(
            bounds.cursors.map { ($0.opaqueFileID, $0.nextByteOffset) },
            uniquingKeysWith: { _, latest in latest }
        )
        let baselines = parentBaselines(in: parsedFiles)
        let requests = reconcile(
            parsedFiles,
            priorOffsets: priorOffsets,
            parentBaselines: baselines
        )
        let cursors = parsedFiles
            .map { LocalActivityFileCursor(opaqueFileID: $0.opaqueFileID, nextByteOffset: $0.nextOffset) }
            .sorted { $0.opaqueFileID < $1.opaqueFileID }
        return LocalActivityScanResult(requests: requests, cursors: cursors, status: .readable)
    }

    private func regularJSONLFiles() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: sessionsRoot.path) else { return [] }
        let rootValues = try sessionsRoot.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
        ])
        guard rootValues.isSymbolicLink != true else {
            throw CocoaError(.fileReadNoPermission)
        }
        guard rootValues.isDirectory == true else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var files: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true, item.pathExtension.lowercased() == "jsonl" else {
                continue
            }
            files.append(item)
        }
        return files.sorted { $0.path < $1.path }
    }

    private func parse(
        result: LocalActivityJSONLReader.Result,
        opaqueFileID: String
    ) -> ParsedFile {
        let decoder = JSONDecoder()
        var metadata: SessionMetadata?
        var currentModel: String?
        var currentTurnID: String?
        var events: [UsageEvent] = []

        for line in result.lines {
            guard let record = try? decoder.decode(Record.self, from: line.bytes) else { continue }
            switch record.type {
            case "session_meta":
                if metadata == nil {
                    metadata = SessionMetadata(
                        sessionID: record.payload?.sessionID ?? record.sessionID,
                        parentSessionID: record.payload?.parentSessionID,
                        forkedAt: Self.date(record.payload?.timestamp ?? record.timestamp)
                    )
                }
            case "turn_context":
                if let model = record.payload?.modelIdentifier {
                    currentModel = model
                }
            case "event_msg":
                guard let payload = record.payload else { continue }
                if payload.type == "task_started" {
                    currentTurnID = payload.turnID ?? currentTurnID
                    continue
                }
                guard payload.type == "token_count",
                      let timestamp = Self.date(record.timestamp)
                else { continue }
                let last = payload.info?.lastTokenUsage.flatMap(Totals.init)
                let total = payload.info?.totalTokenUsage.flatMap(Totals.init)
                guard last != nil || total != nil else { continue }
                events.append(UsageEvent(
                    timestamp: timestamp,
                    lineOffset: line.startOffset,
                    eventIdentity: "\(opaqueFileID):\(line.startOffset)",
                    turnID: payload.turnID ?? currentTurnID,
                    modelID: currentModel ?? payload.modelIdentifier ?? payload.info?.modelIdentifier,
                    last: last,
                    total: total
                ))
            default:
                continue
            }
        }

        return ParsedFile(
            opaqueFileID: opaqueFileID,
            nextOffset: result.nextOffset,
            metadata: metadata,
            events: events
        )
    }

    private func parentBaselines(in files: [ParsedFile]) -> [ParentBaselineKey: Totals] {
        let bySession = Dictionary(grouping: files.compactMap { file -> (String, ParsedFile)? in
            file.metadata?.sessionID.map { ($0, file) }
        }, by: \.0)
        var result: [ParentBaselineKey: Totals] = [:]
        for file in files {
            guard let parentID = file.metadata?.parentSessionID,
                  let forkedAt = file.metadata?.forkedAt
            else { continue }
            let parentEvents = (bySession[parentID] ?? []).flatMap(\.1.events)
                .filter { $0.timestamp <= forkedAt }
                .sorted(by: UsageEvent.order)
            var watermark: Totals?
            var counted = Totals.zero
            for event in parentEvents {
                if let total = event.total {
                    watermark = watermark.map { $0.maximum(total) } ?? total
                } else if let last = event.last {
                    counted = counted.adding(last) ?? counted
                    watermark = watermark.map { $0.maximum(counted) } ?? counted
                }
            }
            if let watermark {
                result[ParentBaselineKey(parentID: parentID, forkedAt: forkedAt)] = watermark
            }
        }
        return result
    }

    private func reconcile(
        _ files: [ParsedFile],
        priorOffsets: [String: Int64],
        parentBaselines: [ParentBaselineKey: Totals]
    ) -> [LocalActivityRequest] {
        let grouped = Dictionary(grouping: files) {
            $0.metadata?.sessionID ?? "file:\($0.opaqueFileID)"
        }
        var requests: [LocalActivityRequest] = []

        for (sessionKey, sessionFiles) in grouped {
            let metadata = sessionFiles.compactMap(\.metadata).first
            let inherited = metadata.flatMap { metadata -> Totals? in
                guard let parentID = metadata.parentSessionID, let forkedAt = metadata.forkedAt else { return nil }
                return parentBaselines[ParentBaselineKey(parentID: parentID, forkedAt: forkedAt)]
            }
            let hasUnresolvedParent = metadata?.parentSessionID != nil && inherited == nil
            var tracker = TotalsTracker()
            var remainingInherited = inherited
            var skippedUnresolvedPrefix = false

            let events = sessionFiles.flatMap { file in
                file.events.map { (file, $0) }
            }.sorted {
                if $0.1.timestamp == $1.1.timestamp {
                    if $0.0.opaqueFileID == $1.0.opaqueFileID {
                        return $0.1.lineOffset < $1.1.lineOffset
                    }
                    return $0.0.opaqueFileID < $1.0.opaqueFileID
                }
                return $0.1.timestamp < $1.1.timestamp
            }

            for (file, event) in events {
                var last = event.last
                var total = event.total
                if let inherited {
                    total = total?.subtractingFloorZero(inherited)
                    if let rawLast = last, let remaining = remainingInherited {
                        if total == .zero {
                            last = rawLast.subtractingFloorZero(remaining)
                            remainingInherited = remaining.subtractingFloorZero(rawLast)
                            if remainingInherited == .zero { remainingInherited = nil }
                        } else {
                            // A positive parent-adjusted total is already an owned child suffix.
                            // Its reported last usage is local, not another copied-prefix slice.
                            remainingInherited = nil
                        }
                    }
                } else if hasUnresolvedParent, let total, !skippedUnresolvedPrefix {
                    skippedUnresolvedPrefix = true
                    tracker.observeWithoutCounting(total)
                    continue
                }

                guard let delta = tracker.accept(last: last, total: total),
                      delta != .zero,
                      let tokens = LocalActivityTokenBreakdown(
                        provider: .codex,
                        inputTokens: delta.input,
                        cachedInputTokens: delta.cached,
                        outputTokens: delta.output,
                        reasoningOutputTokens: delta.reasoning
                      )
                else { continue }

                let priorOffset = priorOffsets[file.opaqueFileID] ?? 0
                guard priorOffset > file.nextOffset || event.lineOffset >= priorOffset else { continue }
                let identity = [
                    "codex",
                    sessionKey,
                    event.turnID ?? "",
                    event.eventIdentity,
                    delta.identity,
                ].joined(separator: "|")
                requests.append(LocalActivityRequest(
                    id: Self.digest(identity),
                    provider: .codex,
                    occurredAt: event.timestamp,
                    modelID: event.modelID,
                    tokens: tokens
                ))
            }
        }
        return requests.sorted {
            $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt < $1.occurredAt
        }
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return parsed
        }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value)
    }
}

private struct ParsedFile {
    let opaqueFileID: String
    let nextOffset: Int64
    let metadata: SessionMetadata?
    let events: [UsageEvent]
}

private struct SessionMetadata {
    let sessionID: String?
    let parentSessionID: String?
    let forkedAt: Date?
}

private struct ParentBaselineKey: Hashable {
    let parentID: String
    let forkedAt: Date
}

private struct UsageEvent {
    let timestamp: Date
    let lineOffset: Int64
    let eventIdentity: String
    let turnID: String?
    let modelID: String?
    let last: Totals?
    let total: Totals?

    static func order(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.timestamp == rhs.timestamp ? lhs.lineOffset < rhs.lineOffset : lhs.timestamp < rhs.timestamp
    }
}

private struct Totals: Equatable, Hashable {
    let input: Int64
    let cached: Int64
    let output: Int64
    let reasoning: Int64

    static let zero = Self(input: 0, cached: 0, output: 0, reasoning: 0)

    init?(_ usage: TokenUsage) {
        let input = usage.inputTokens ?? 0
        let cached = usage.cachedInputTokens ?? usage.cacheReadInputTokens ?? 0
        let output = usage.outputTokens ?? 0
        let reasoning = usage.reasoningOutputTokens ?? 0
        let normalizedTotal = input.addingReportingOverflow(output)
        guard input >= 0, cached >= 0, output >= 0, reasoning >= 0,
              cached <= input, reasoning <= output,
              !normalizedTotal.overflow,
              usage.totalTokens.map({ $0 == normalizedTotal.partialValue }) ?? true
        else { return nil }
        self.init(input: input, cached: cached, output: output, reasoning: reasoning)
    }

    init(input: Int64, cached: Int64, output: Int64, reasoning: Int64) {
        self.input = input
        self.cached = cached
        self.output = output
        self.reasoning = reasoning
    }

    var identity: String {
        "\(input):\(cached):\(output):\(reasoning)"
    }

    func adding(_ other: Self) -> Self? {
        func add(_ lhs: Int64, _ rhs: Int64) -> Int64? {
            let value = lhs.addingReportingOverflow(rhs)
            return value.overflow ? nil : value.partialValue
        }
        guard let input = add(input, other.input),
              let cached = add(cached, other.cached),
              let output = add(output, other.output),
              let reasoning = add(reasoning, other.reasoning)
        else { return nil }
        return Self(input: input, cached: cached, output: output, reasoning: reasoning)
    }

    func subtractingFloorZero(_ other: Self) -> Self {
        Self(
            input: max(0, input - other.input),
            cached: max(0, cached - other.cached),
            output: max(0, output - other.output),
            reasoning: max(0, reasoning - other.reasoning)
        )
    }

    func minimum(_ other: Self) -> Self {
        Self(
            input: min(input, other.input),
            cached: min(cached, other.cached),
            output: min(output, other.output),
            reasoning: min(reasoning, other.reasoning)
        )
    }

    func maximum(_ other: Self) -> Self {
        Self(
            input: max(input, other.input),
            cached: max(cached, other.cached),
            output: max(output, other.output),
            reasoning: max(reasoning, other.reasoning)
        )
    }

    func isAtMost(_ other: Self) -> Bool {
        input <= other.input && cached <= other.cached && output <= other.output && reasoning <= other.reasoning
    }

    func isAtLeast(_ other: Self) -> Bool {
        input >= other.input && cached >= other.cached && output >= other.output && reasoning >= other.reasoning
    }
}

private struct TotalsTracker {
    private var counted = Totals.zero
    private var rawBaseline: Totals?
    private var watermark: Totals?
    private var seen: Set<Totals> = []
    private var divergent = false
    private var interleaved = false

    mutating func observeWithoutCounting(_ total: Totals) {
        latch(total)
        commit(total)
    }

    mutating func accept(last: Totals?, total: Totals?) -> Totals? {
        if let total {
            guard !seen.contains(total) else { return nil }
            latch(total)
        }
        let baseline = watermark ?? rawBaseline
        defer {
            if let total { commit(total) }
        }

        let delta: Totals
        if let total {
            let totalDelta = total.subtractingFloorZero(baseline ?? .zero)
            if interleaved {
                let contained = Totals(
                    input: containedComponent(water: baseline?.input ?? 0, current: total.input, counted: counted.input),
                    cached: containedComponent(water: baseline?.cached ?? 0, current: total.cached, counted: counted.cached),
                    output: containedComponent(water: baseline?.output ?? 0, current: total.output, counted: counted.output),
                    reasoning: containedComponent(
                        water: baseline?.reasoning ?? 0,
                        current: total.reasoning,
                        counted: counted.reasoning
                    )
                )
                delta = last.map { contained.minimum($0) } ?? contained
            } else if let last,
                      total.isAtLeast(baseline ?? .zero),
                      totalDelta != .zero,
                      totalDelta.isAtMost(last),
                      !divergent {
                delta = totalDelta
            } else if let last {
                delta = last
            } else {
                delta = totalDelta
            }
            counted = counted.adding(delta) ?? counted
            rawBaseline = total
            divergent = divergent || counted != total
            return delta
        }
        guard let last, let next = counted.adding(last) else { return nil }
        counted = next
        rawBaseline = next
        watermark = watermark.map { $0.maximum(next) } ?? next
        return last
    }

    private mutating func latch(_ total: Totals) {
        if let watermark, !total.isAtLeast(watermark) {
            interleaved = true
        }
    }

    private mutating func commit(_ total: Totals) {
        watermark = watermark.map { $0.maximum(total) } ?? total
        seen.insert(total)
    }

    private func containedComponent(water: Int64, current: Int64, counted: Int64) -> Int64 {
        if current >= water {
            return max(0, current - max(water, counted))
        }
        return max(0, current - counted)
    }
}

private struct Record: Decodable {
    let timestamp: String?
    let type: String
    let sessionID: String?
    let payload: RecordPayload?

    enum CodingKeys: String, CodingKey {
        case timestamp, type, payload
        case sessionID = "session_id"
    }
}

private struct RecordPayload: Decodable {
    let type: String?
    let id: String?
    let sessionIDSnake: String?
    let sessionIDCamel: String?
    let forkedFromIDSnake: String?
    let forkedFromIDCamel: String?
    let parentSessionIDSnake: String?
    let parentSessionIDCamel: String?
    let timestamp: String?
    let turnIDSnake: String?
    let turnIDCamel: String?
    let model: String?
    let modelName: String?
    let info: TokenInfo?

    var sessionID: String? { id ?? sessionIDSnake ?? sessionIDCamel }
    var parentSessionID: String? {
        forkedFromIDSnake ?? forkedFromIDCamel ?? parentSessionIDSnake ?? parentSessionIDCamel
    }
    var turnID: String? { turnIDSnake ?? turnIDCamel }
    var modelIdentifier: String? { Self.nonempty(model) ?? Self.nonempty(modelName) }

    enum CodingKeys: String, CodingKey {
        case type, id, timestamp, model, info
        case sessionIDSnake = "session_id"
        case sessionIDCamel = "sessionId"
        case forkedFromIDSnake = "forked_from_id"
        case forkedFromIDCamel = "forkedFromId"
        case parentSessionIDSnake = "parent_session_id"
        case parentSessionIDCamel = "parentSessionId"
        case turnIDSnake = "turn_id"
        case turnIDCamel = "turnId"
        case modelName = "model_name"
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct TokenInfo: Decodable {
    let model: String?
    let modelName: String?
    let lastTokenUsage: TokenUsage?
    let totalTokenUsage: TokenUsage?

    var modelIdentifier: String? {
        let value = model ?? modelName
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    enum CodingKeys: String, CodingKey {
        case model
        case modelName = "model_name"
        case lastTokenUsage = "last_token_usage"
        case totalTokenUsage = "total_token_usage"
    }
}

private struct TokenUsage: Decodable {
    let inputTokens: Int64?
    let cachedInputTokens: Int64?
    let cacheReadInputTokens: Int64?
    let outputTokens: Int64?
    let reasoningOutputTokens: Int64?
    let totalTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}
