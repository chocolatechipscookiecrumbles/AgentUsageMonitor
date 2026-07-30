import CryptoKit
import Foundation

actor CodexLocalActivitySource: LocalActivitySource {
    nonisolated let provider: AgentProvider = .codex

    private let sessionsRoot: URL
    private let traversal = LocalActivityFileTraversal()
    /// Decoded per-file parser state, kept only in memory and only for the
    /// files still present at the last scan. Session transcripts hold full
    /// conversation content, so re-decoding every one of them on each file
    /// event would cost seconds of CPU for a single appended usage record.
    private var parseCache: [String: ParsedFile] = [:]

    init(
        sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    ) {
        self.sessionsRoot = sessionsRoot
    }

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        do {
            let cache = parseCache
            let parsedFiles = try await traversal.parseJSONLFiles(
                root: sessionsRoot,
                resume: { fingerprint, fileDescriptor in
                    LocalActivityResumePoint.decide(
                        fingerprint: fingerprint,
                        cached: cache[fingerprint.opaqueFileID],
                        fileDescriptor: fileDescriptor
                    )
                },
                makeState: { FileParseState(opaqueFileID: $0) },
                consume: { state, line in try state.consume(line) },
                finish: { fingerprint, state, nextOffset in
                    state.finished(fingerprint: fingerprint, nextOffset: nextOffset)
                }
            )
            try Task.checkCancellation()
            // Rebuilding rather than merging drops files that no longer exist.
            parseCache = Dictionary(
                parsedFiles.map { ($0.opaqueFileID, $0) },
                uniquingKeysWith: { _, latest in latest }
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

    func reset() {
        parseCache.removeAll(keepingCapacity: false)
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

            let parentEvents = UsageEvent.ordered(
                parentFiles.flatMap(\.1.events).filter { $0.timestamp <= forkedAt }
            )
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
            // Every event here shares one session, so the session-independent
            // ordering identity gives the same deterministic order without
            // hashing inside the comparator.
            var decorated: [(file: ParsedFile, event: UsageEvent, orderingKey: String)] = []
            for file in sessionFiles {
                for event in file.events {
                    decorated.append((file, event, event.orderingIdentity))
                }
            }
            decorated.sort { lhs, rhs in
                lhs.event.timestamp == rhs.event.timestamp
                    ? lhs.orderingKey < rhs.orderingKey
                    : lhs.event.timestamp < rhs.event.timestamp
            }
            let events: [(ParsedFile, UsageEvent)] = decorated.map { ($0.file, $0.event) }

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
        LocalActivityIdentity.digest(fields)
    }

    fileprivate static func date(_ value: String?) -> Date? {
        LocalActivityTimestamp.date(value)
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

    func finished(fingerprint: LocalActivityFileFingerprint, nextOffset: Int64) -> ParsedFile {
        ParsedFile(fingerprint: fingerprint, nextOffset: nextOffset, parserState: self)
    }
}

private struct ParsedFile: LocalActivityParsedFile {
    let fingerprint: LocalActivityFileFingerprint
    let nextOffset: Int64
    let parserState: FileParseState

    var opaqueFileID: String { fingerprint.opaqueFileID }
    var metadata: SessionMetadata? { parserState.metadata }
    var events: [UsageEvent] { parserState.events }
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
    /// Deterministic tie-break for events sharing a timestamp, hashed once when
    /// the record is first parsed. Parsed files are cached across scans, so a
    /// rescan of unchanged history pays nothing for ordering.
    let orderingIdentity: String

    init(
        timestamp: Date,
        timestampIdentity: String,
        lineOffset: Int64,
        providerEventID: String?,
        turnID: String?,
        modelID: String?,
        last: Totals?,
        total: Totals?
    ) {
        self.timestamp = timestamp
        self.timestampIdentity = timestampIdentity
        self.lineOffset = lineOffset
        self.providerEventID = providerEventID
        self.turnID = turnID
        self.modelID = modelID
        self.last = last
        self.total = total

        var fields = Self.identityFields(
            sessionKey: "",
            providerEventID: providerEventID,
            turnID: turnID,
            timestampIdentity: timestampIdentity,
            modelID: modelID,
            last: last,
            total: total
        )
        fields.append(contentsOf: ["timestamp", timestampIdentity, "last"])
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: last))
        fields.append("total")
        fields.append(contentsOf: CodexLocalActivitySource.framingFields(for: total))
        orderingIdentity = CodexLocalActivitySource.digest(fields)
    }

    /// Sorts by time with a deterministic tie-break. The ordering identity is
    /// hashed once per event rather than inside the comparator, which would
    /// otherwise cost hundreds of thousands of digests on a full session root.
    static func ordered(_ events: [Self]) -> [Self] {
        var decorated: [(event: Self, orderingKey: String)] = []
        decorated.reserveCapacity(events.count)
        for event in events {
            decorated.append((event, event.orderingIdentity))
        }
        decorated.sort { lhs, rhs in
            lhs.event.timestamp == rhs.event.timestamp
                ? lhs.orderingKey < rhs.orderingKey
                : lhs.event.timestamp < rhs.event.timestamp
        }
        return decorated.map(\.event)
    }

    func logicalIdentityFields(sessionKey: String) -> [String] {
        Self.identityFields(
            sessionKey: sessionKey,
            providerEventID: providerEventID,
            turnID: turnID,
            timestampIdentity: timestampIdentity,
            modelID: modelID,
            last: last,
            total: total
        )
    }

    /// A provider event ID identifies the event only within its session and
    /// turn, so those always frame it. Without one, the record's own timestamp,
    /// usage, and model stand in.
    private static func identityFields(
        sessionKey: String,
        providerEventID: String?,
        turnID: String?,
        timestampIdentity: String,
        modelID: String?,
        last: Totals?,
        total: Totals?
    ) -> [String] {
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
