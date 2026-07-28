import CryptoKit
import Foundation

struct CodexLocalActivitySource: LocalActivitySource {
    let provider: AgentProvider = .codex

    private let sessionsRoot: URL
    private let traversal = LocalActivityFileTraversal()

    init(
        sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    ) {
        self.sessionsRoot = sessionsRoot
    }

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        do {
            let parsedFiles = try await traversal.parseJSONLFiles(
                root: sessionsRoot,
                makeState: { FileParseState(opaqueFileID: $0) },
                consume: { state, line in try state.consume(line) },
                finish: { state, nextOffset in state.finished(nextOffset: nextOffset) }
            )
            guard !parsedFiles.isEmpty else {
                return LocalActivityScanResult(requests: [], cursors: [], status: .localRecordsMissing)
            }

            let priorOffsets = Dictionary(
                bounds.cursors.map { ($0.opaqueFileID, $0.nextByteOffset) },
                uniquingKeysWith: { _, latest in latest }
            )
            let baselines = try parentBaselines(in: parsedFiles)
            let requests = try reconcile(
                parsedFiles,
                priorOffsets: priorOffsets,
                parentBaselines: baselines
            )
            let cursors = parsedFiles
                .map { LocalActivityFileCursor(opaqueFileID: $0.opaqueFileID, nextByteOffset: $0.nextOffset) }
                .sorted { $0.opaqueFileID < $1.opaqueFileID }
            return LocalActivityScanResult(requests: requests, cursors: cursors, status: .readable)
        } catch LocalActivityFileTraversal.TraversalFailure.rootMissing {
            return LocalActivityScanResult(requests: [], cursors: [], status: .localRecordsMissing)
        } catch {
            return LocalActivityScanResult(requests: [], cursors: [], status: .unsafeToRead)
        }
    }

    private func parentBaselines(in files: [ParsedFile]) throws -> [ParentBaselineKey: Totals] {
        let bySession = Dictionary(grouping: files.compactMap { file -> (String, ParsedFile)? in
            file.metadata?.sessionID.map { ($0, file) }
        }, by: \.0)
        var result: [ParentBaselineKey: Totals] = [:]

        for file in files {
            guard let parentID = file.metadata?.parentSessionID,
                  let forkedAt = file.metadata?.forkedAt,
                  let parentFiles = bySession[parentID]
            else { continue }

            let parentEvents = parentFiles.flatMap(\.1.events)
                .filter { $0.timestamp <= forkedAt }
                .sorted(by: UsageEvent.order)
            var watermark = Totals.zero
            var countedLastOnly = Totals.zero
            for event in parentEvents {
                if let total = event.total {
                    watermark = watermark.maximum(total)
                } else if let last = event.last {
                    countedLastOnly = try countedLastOnly.adding(last)
                    watermark = watermark.maximum(countedLastOnly)
                }
            }
            result[ParentBaselineKey(parentID: parentID, forkedAt: forkedAt)] = watermark
        }
        return result
    }

    private func reconcile(
        _ files: [ParsedFile],
        priorOffsets: [String: Int64],
        parentBaselines: [ParentBaselineKey: Totals]
    ) throws -> [LocalActivityRequest] {
        let grouped = Dictionary(grouping: files) {
            $0.metadata?.sessionID ?? "file:\($0.opaqueFileID)"
        }
        var requests: [LocalActivityRequest] = []

        for (groupingKey, sessionFiles) in grouped {
            let metadata = try consistentMetadata(in: sessionFiles)
            let sessionIdentity = metadata?.sessionID
            let orderingSessionIdentity = sessionIdentity ?? groupingKey
            let events = sessionFiles.flatMap { file in
                file.events.map { (file, $0) }
            }.sorted {
                if $0.1.timestamp == $1.1.timestamp {
                    return Self.digest(
                        $0.1.logicalIdentityFields(sessionKey: orderingSessionIdentity)
                    ) < Self.digest(
                        $1.1.logicalIdentityFields(sessionKey: orderingSessionIdentity)
                    )
                }
                return $0.1.timestamp < $1.1.timestamp
            }

            guard events.isEmpty || sessionIdentity != nil else {
                throw CodexLocalActivityFailure.malformedRecord
            }
            let inherited: Totals?
            if let parentID = metadata?.parentSessionID {
                guard events.isEmpty || metadata?.forkedAt != nil else {
                    throw CodexLocalActivityFailure.unresolvedFork
                }
                if events.isEmpty {
                    inherited = nil
                } else {
                    guard let forkedAt = metadata?.forkedAt,
                          let baseline = parentBaselines[
                            ParentBaselineKey(parentID: parentID, forkedAt: forkedAt)
                          ]
                    else {
                        throw CodexLocalActivityFailure.unresolvedFork
                    }
                    inherited = baseline
                }
            } else {
                inherited = nil
            }

            var tracker = TotalsTracker()
            var remainingInherited = inherited
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
                            remainingInherited = nil
                        }
                    }
                }

                guard let delta = try tracker.accept(last: last, total: total) else { continue }
                if delta == .zero { continue }
                guard let tokens = LocalActivityTokenBreakdown(
                    provider: .codex,
                    inputTokens: delta.input,
                    cachedInputTokens: delta.cached,
                    outputTokens: delta.output,
                    reasoningOutputTokens: delta.reasoning
                ) else {
                    throw CodexLocalActivityFailure.invalidReconciledUsage
                }

                let priorOffset = priorOffsets[file.opaqueFileID] ?? 0
                guard priorOffset > file.nextOffset || event.lineOffset >= priorOffset else { continue }
                var requestIdentity = [
                    "provider",
                    "codex",
                ]
                requestIdentity.append(contentsOf: event.logicalIdentityFields(
                    sessionKey: sessionIdentity ?? groupingKey
                ))
                requestIdentity.append("reconciled-delta")
                requestIdentity.append(contentsOf: delta.framingFields)
                requestIdentity.append("reconciled-total")
                requestIdentity.append(contentsOf: Self.framingFields(for: total))
                requests.append(LocalActivityRequest(
                    id: Self.digest(requestIdentity),
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

    private func consistentMetadata(in files: [ParsedFile]) throws -> SessionMetadata? {
        let metadata = files.compactMap(\.metadata)
        guard let first = metadata.first else { return nil }
        guard metadata.dropFirst().allSatisfy({
            $0.sessionID == first.sessionID
                && $0.parentSessionID == first.parentSessionID
                && $0.forkedAt == first.forkedAt
        }) else {
            throw CodexLocalActivityFailure.conflictingMetadata
        }
        return first
    }

    fileprivate static func framingFields(for totals: Totals?) -> [String] {
        guard let totals else { return ["absent"] }
        return ["present"] + totals.framingFields
    }

    fileprivate static func digest(_ fields: [String]) -> String {
        var framed = Data()
        var fieldCount = UInt64(fields.count).bigEndian
        withUnsafeBytes(of: &fieldCount) { framed.append(contentsOf: $0) }
        for field in fields {
            let bytes = Data(field.utf8)
            var byteCount = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &byteCount) { framed.append(contentsOf: $0) }
            framed.append(bytes)
        }
        return SHA256.hash(data: framed).map { String(format: "%02x", $0) }.joined()
    }

    fileprivate static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return parsed
        }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value)
    }
}

private enum CodexLocalActivityFailure: Error {
    case malformedRecord
    case malformedUsage
    case arithmeticOverflow
    case unresolvedFork
    case conflictingMetadata
    case invalidReconciledUsage
}

private struct FileParseState: Sendable {
    let opaqueFileID: String
    private(set) var metadata: SessionMetadata?
    private(set) var currentModel: String?
    private(set) var currentTurnID: String?
    private(set) var events: [UsageEvent] = []

    mutating func consume(_ line: LocalActivityJSONLReader.Line) throws {
        let record: Record
        do {
            record = try JSONDecoder().decode(Record.self, from: line.bytes)
        } catch {
            throw CodexLocalActivityFailure.malformedRecord
        }

        let recordType = record.type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recordType.isEmpty else {
            throw CodexLocalActivityFailure.malformedRecord
        }

        switch recordType {
        case "session_meta":
            if metadata == nil {
                let topLevelSessionID = record.sessionID?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                metadata = SessionMetadata(
                    sessionID: record.payload?.sessionID
                        ?? (topLevelSessionID?.isEmpty == false ? topLevelSessionID : nil),
                    parentSessionID: record.payload?.parentSessionID,
                    forkedAt: CodexLocalActivitySource.date(record.payload?.timestamp ?? record.timestamp)
                )
            }
        case "turn_context":
            if let model = record.payload?.modelIdentifier {
                currentModel = model
            }
        case "event_msg":
            guard let payload = record.payload,
                  let payloadType = payload.type?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !payloadType.isEmpty
            else {
                throw CodexLocalActivityFailure.malformedRecord
            }
            if payloadType == "task_started" {
                currentTurnID = payload.turnID ?? currentTurnID
                return
            }
            guard payloadType == "token_count" else { return }
            // Codex also emits rate-limit-only `token_count` records whose
            // `info` is null. Those make no usage claim at all, so they are
            // ignorable like any other non-usage subtype rather than missing
            // evidence. A usage object that *is* present stays strict below.
            guard let info = payload.info else { return }
            guard let rawTimestamp = record.timestamp,
                  let timestamp = CodexLocalActivitySource.date(rawTimestamp),
                  let turnID = payload.turnID ?? currentTurnID
            else {
                throw CodexLocalActivityFailure.malformedUsage
            }
            let last = try info.lastTokenUsage.map(Totals.init)
            let total = try info.totalTokenUsage.map(Totals.init)
            guard last != nil || total != nil else {
                throw CodexLocalActivityFailure.malformedUsage
            }
            events.append(UsageEvent(
                timestamp: timestamp,
                timestampIdentity: rawTimestamp,
                lineOffset: line.startOffset,
                providerEventID: payload.providerEventID,
                turnID: turnID,
                modelID: currentModel ?? payload.modelIdentifier ?? info.modelIdentifier,
                last: last,
                total: total
            ))
        default:
            return
        }
    }

    func finished(nextOffset: Int64) -> ParsedFile {
        ParsedFile(
            opaqueFileID: opaqueFileID,
            nextOffset: nextOffset,
            metadata: metadata,
            events: events
        )
    }
}

private struct ParsedFile: Sendable {
    let opaqueFileID: String
    let nextOffset: Int64
    let metadata: SessionMetadata?
    let events: [UsageEvent]
}

private struct SessionMetadata: Sendable, Equatable {
    let sessionID: String?
    let parentSessionID: String?
    let forkedAt: Date?
}

private struct ParentBaselineKey: Hashable {
    let parentID: String
    let forkedAt: Date
}

private struct UsageEvent: Sendable {
    let timestamp: Date
    let timestampIdentity: String
    let lineOffset: Int64
    let providerEventID: String?
    let turnID: String?
    let modelID: String?
    let last: Totals?
    let total: Totals?

    static func order(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.orderingIdentity < rhs.orderingIdentity
    }

    func logicalIdentityFields(sessionKey: String) -> [String] {
        var fields = [
            "session",
            sessionKey,
            "turn",
            turnID ?? "",
        ]
        if let providerEventID {
            fields.append(contentsOf: [
                "provider-event",
                providerEventID,
            ])
            return fields
        }
        fields.append(contentsOf: [
            "fallback-event",
            "timestamp",
            timestampIdentity,
            "last",
        ])
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: last))
        fields.append("total")
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: total))
        fields.append(contentsOf: [
            "model",
            modelID ?? "",
        ])
        return fields
    }

    private var orderingIdentity: String {
        var fields = logicalIdentityFields(sessionKey: "")
        fields.append(contentsOf: [
            "timestamp",
            timestampIdentity,
            "last",
        ])
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: last))
        fields.append("total")
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: total))
        return CodexLocalActivitySource.digest(fields)
    }
}

private struct Totals: Sendable, Equatable, Hashable {
    let input: Int64
    let cached: Int64
    let output: Int64
    let reasoning: Int64

    static let zero = Self(input: 0, cached: 0, output: 0, reasoning: 0)

    init(_ usage: TokenUsage) throws {
        guard let input = usage.inputTokens,
              let cached = usage.cachedInputTokens,
              let output = usage.outputTokens,
              let reasoning = usage.reasoningOutputTokens
        else {
            throw CodexLocalActivityFailure.malformedUsage
        }
        // The normalized Codex total is the reported `total_tokens` when it is
        // internally consistent and `input + output` otherwise, which are the
        // same number whenever the record agrees. Codex does emit records whose
        // reported total disagrees, so an inconsistent one is ignored rather
        // than treated as unsafe evidence; the component values still decide.
        let normalizedTotal = input.addingReportingOverflow(output)
        guard input >= 0, cached >= 0, output >= 0, reasoning >= 0,
              cached <= input, reasoning <= output,
              !normalizedTotal.overflow
        else {
            throw CodexLocalActivityFailure.malformedUsage
        }
        self.init(input: input, cached: cached, output: output, reasoning: reasoning)
    }

    init(input: Int64, cached: Int64, output: Int64, reasoning: Int64) {
        self.input = input
        self.cached = cached
        self.output = output
        self.reasoning = reasoning
    }

    var framingFields: [String] {
        [
            String(input),
            String(cached),
            String(output),
            String(reasoning),
        ]
    }

    func adding(_ other: Self) throws -> Self {
        func add(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
            let value = lhs.addingReportingOverflow(rhs)
            guard !value.overflow else { throw CodexLocalActivityFailure.arithmeticOverflow }
            return value.partialValue
        }
        return try Self(
            input: add(input, other.input),
            cached: add(cached, other.cached),
            output: add(output, other.output),
            reasoning: add(reasoning, other.reasoning)
        )
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

    mutating func accept(last: Totals?, total: Totals?) throws -> Totals? {
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
                let watermark = baseline ?? .zero
                let contained = total.subtractingFloorZero(watermark)
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
            counted = try counted.adding(delta)
            rawBaseline = total
            divergent = divergent || counted != total
            return delta
        }
        guard let last else { throw CodexLocalActivityFailure.malformedUsage }
        counted = try counted.adding(last)
        rawBaseline = counted
        watermark = watermark.map { $0.maximum(counted) } ?? counted
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
    let eventIDSnake: String?
    let eventIDCamel: String?
    let requestIDSnake: String?
    let requestIDCamel: String?
    let model: String?
    let modelName: String?
    let info: TokenInfo?

    var sessionID: String? { nonempty(id) ?? nonempty(sessionIDSnake) ?? nonempty(sessionIDCamel) }
    var parentSessionID: String? {
        nonempty(forkedFromIDSnake)
            ?? nonempty(forkedFromIDCamel)
            ?? nonempty(parentSessionIDSnake)
            ?? nonempty(parentSessionIDCamel)
    }
    var turnID: String? { nonempty(turnIDSnake) ?? nonempty(turnIDCamel) }
    var providerEventID: String? {
        nonempty(eventIDSnake)
            ?? nonempty(eventIDCamel)
            ?? nonempty(requestIDSnake)
            ?? nonempty(requestIDCamel)
            ?? nonempty(id)
    }
    var modelIdentifier: String? { nonempty(model) ?? nonempty(modelName) }

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
        case eventIDSnake = "event_id"
        case eventIDCamel = "eventId"
        case requestIDSnake = "request_id"
        case requestIDCamel = "requestId"
        case modelName = "model_name"
    }

    private func nonempty(_ value: String?) -> String? {
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
    let outputTokens: Int64?
    let reasoningOutputTokens: Int64?
    let totalTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}
