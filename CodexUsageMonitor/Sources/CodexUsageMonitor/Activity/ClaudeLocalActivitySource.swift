import Foundation

/// Reads Claude Code's project transcripts and reconciles them into one request
/// per assistant message.
///
/// Claude writes the same assistant message more than once: streaming chunks
/// repeat a growing cumulative usage object under one `(message id, request id)`
/// pair, and a subagent transcript can replay a parent message under its own
/// request id. Both collapse here, before any aggregation sees them, so replayed
/// copies cannot inflate the graph while genuinely distinct subagent and
/// sidechain responses still count.
actor ClaudeLocalActivitySource: LocalActivitySource {
    nonisolated let provider: AgentProvider = .claudeCode

    private let projectRoots: [URL]
    private let traversal = LocalActivityFileTraversal()
    /// Decoded per-file parser state, in memory only, holding just the files
    /// present at the last scan.
    private var parseCache: [String: ParsedClaudeFile] = [:]

    init(projectRoots: [URL]) {
        self.projectRoots = projectRoots
    }

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(projectRoots: Self.defaultProjectRoots(environment: environment))
    }

    /// `CLAUDE_CONFIG_DIR` may name several comma-separated configuration
    /// directories and replaces the defaults when it names at least one usable
    /// absolute path.
    static func defaultProjectRoots(environment: [String: String]) -> [URL] {
        let configured = (environment["CLAUDE_CONFIG_DIR"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("/") }
            .map {
                URL(fileURLWithPath: $0, isDirectory: true)
                    .appendingPathComponent("projects", isDirectory: true)
            }
        guard configured.isEmpty else { return configured }

        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".claude/projects", isDirectory: true),
            home.appendingPathComponent(".config/claude/projects", isDirectory: true),
        ]
    }

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult {
        do {
            var parsedFiles: [ParsedClaudeFile] = []
            var seenFileIDs: Set<String> = []
            var anyRootExists = false
            var skippedFileCount = 0
            let cache = parseCache

            for root in projectRoots {
                let outcome: LocalActivityFileTraversal.Outcome<ParsedClaudeFile>
                do {
                    outcome = try await traversal.parseJSONLFiles(
                        root: root,
                        resume: { fingerprint, fileDescriptor in
                            LocalActivityResumePoint.decide(
                                fingerprint: fingerprint,
                                cached: cache[fingerprint.opaqueFileID],
                                fileDescriptor: fileDescriptor
                            )
                        },
                        makeState: { ClaudeFileParseState(opaqueFileID: $0) },
                        consume: { state, line in try state.consume(line) },
                        finish: { fingerprint, state, nextOffset in
                            state.finished(fingerprint: fingerprint, nextOffset: nextOffset)
                        }
                    )
                } catch LocalActivityFileTraversal.TraversalFailure.rootMissing {
                    continue
                }
                anyRootExists = true
                skippedFileCount += outcome.skippedFileCount
                // Configured roots can resolve to the same directory, and the
                // same file must not be parsed twice under two cursors.
                parsedFiles.append(
                    contentsOf: outcome.parsed.filter { seenFileIDs.insert($0.opaqueFileID).inserted }
                )
            }

            try Task.checkCancellation()
            // Rebuilding rather than merging drops files that no longer exist.
            parseCache = Dictionary(
                parsedFiles.map { ($0.opaqueFileID, $0) },
                uniquingKeysWith: { _, latest in latest }
            )

            guard anyRootExists, !parsedFiles.isEmpty else {
                // A root that exists but yielded nothing readable is not the
                // same as one with no records in it.
                return LocalActivityScanResult(
                    requests: [],
                    cursors: [],
                    status: anyRootExists && skippedFileCount > 0 ? .unsafeToRead : .localRecordsMissing
                )
            }

            let priorOffsets = Dictionary(
                bounds.cursors.map { ($0.opaqueFileID, $0.nextByteOffset) },
                uniquingKeysWith: { _, latest in latest }
            )
            let requests = try reconcile(parsedFiles, priorOffsets: priorOffsets)
            let cursors = parsedFiles
                .map { LocalActivityFileCursor(opaqueFileID: $0.opaqueFileID, nextByteOffset: $0.nextOffset) }
                .sorted { $0.opaqueFileID < $1.opaqueFileID }
            return LocalActivityScanResult(requests: requests, cursors: cursors, status: .readable)
        } catch {
            return LocalActivityScanResult(requests: [], cursors: [], status: .unsafeToRead)
        }
    }

    func reset() {
        parseCache.removeAll(keepingCapacity: false)
    }

    private func reconcile(
        _ files: [ParsedClaudeFile],
        priorOffsets: [String: Int64]
    ) throws -> [LocalActivityRequest] {
        struct StreamingKey: Hashable {
            let messageID: String
            let requestID: String
        }

        // Streaming chunks are cumulative only within one message/request pair.
        // Treating the message alone as the key can collapse two distinct
        // requests when an external record reuses a message identifier.
        var pairWinners: [
            StreamingKey: (file: ParsedClaudeFile, event: ClaudeUsageEvent)
        ] = [:]
        for file in files {
            for event in file.events {
                let key = StreamingKey(
                    messageID: event.messageID,
                    requestID: event.requestID
                )
                guard let incumbent = pairWinners[key] else {
                    pairWinners[key] = (file, event)
                    continue
                }
                if Self.prefers(event, over: incumbent.event) {
                    pairWinners[key] = (file, event)
                }
            }
        }

        // A sidechain transcript can replay a parent response under a different
        // request ID. In the cross-file parent/sidechain shape, every distinct
        // parent pair remains observed and only the sidechain replay candidates
        // are removed. Distinct pairs in one file remain distinct.
        var winners: [(file: ParsedClaudeFile, event: ClaudeUsageEvent)] = []
        for group in Dictionary(grouping: pairWinners.values, by: \.event.messageID).values {
            let fileIDs = Set(group.map(\.file.opaqueFileID))
            let parents = group.filter { !$0.event.isSidechain }
            let hasSidechain = group.contains { $0.event.isSidechain }
            if fileIDs.count > 1, !parents.isEmpty, hasSidechain {
                winners.append(contentsOf: parents)
            } else {
                winners.append(contentsOf: group)
            }
        }

        var requests: [LocalActivityRequest] = []
        requests.reserveCapacity(winners.count)
        for winner in winners {
            guard let tokens = LocalActivityTokenBreakdown(
                provider: .claudeCode,
                inputTokens: winner.event.tokens.input,
                cacheCreationTokens: winner.event.tokens.cacheCreation,
                cachedInputTokens: winner.event.tokens.cacheRead,
                outputTokens: winner.event.tokens.output
            ) else {
                throw ClaudeLocalActivityFailure.invalidReconciledUsage
            }
            // A synthetic assistant message reports no tokens; it is not an
            // observed request and must not become a Requests row or a model group.
            guard tokens.totalTokens > 0 else { continue }

            let priorOffset = priorOffsets[winner.file.opaqueFileID] ?? 0
            guard priorOffset > winner.file.nextOffset || winner.event.lineOffset >= priorOffset else {
                continue
            }

            requests.append(LocalActivityRequest(
                id: LocalActivityIdentity.digest([
                    "provider", "claude-code",
                    "message", winner.event.messageID,
                    "request", winner.event.requestID,
                ]),
                provider: .claudeCode,
                occurredAt: winner.event.timestamp,
                modelID: winner.event.modelID,
                tokens: tokens
            ))
        }
        return requests.sorted {
            $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt < $1.occurredAt
        }
    }

    /// A non-sidechain parent copy beats a replayed sidechain copy. Otherwise
    /// the more complete cumulative record wins, then the newer timestamp, then
    /// a stable digest so repeated scans always agree on the same winner.
    private static func prefers(_ candidate: ClaudeUsageEvent, over incumbent: ClaudeUsageEvent) -> Bool {
        if candidate.isSidechain != incumbent.isSidechain { return !candidate.isSidechain }
        if candidate.tokens.total != incumbent.tokens.total {
            return candidate.tokens.total > incumbent.tokens.total
        }
        if candidate.timestamp != incumbent.timestamp { return candidate.timestamp > incumbent.timestamp }
        return candidate.orderingIdentity < incumbent.orderingIdentity
    }
}

private enum ClaudeLocalActivityFailure: Error {
    case malformedRecord
    case malformedUsage
    case arithmeticOverflow
    case invalidReconciledUsage
}

private struct ParsedClaudeFile: LocalActivityParsedFile {
    let fingerprint: LocalActivityFileFingerprint
    let nextOffset: Int64
    let parserState: ClaudeFileParseState

    var opaqueFileID: String { fingerprint.opaqueFileID }
    var events: [ClaudeUsageEvent] { parserState.events }
}

private struct ClaudeFileParseState: Sendable {
    let opaqueFileID: String
    private(set) var events: [ClaudeUsageEvent] = []

    mutating func consume(_ line: LocalActivityJSONLReader.Line) throws {
        let record: ClaudeRecord
        do {
            record = try JSONDecoder().decode(ClaudeRecord.self, from: line.bytes)
        } catch {
            throw ClaudeLocalActivityFailure.malformedRecord
        }

        let recordType = record.type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recordType.isEmpty else { throw ClaudeLocalActivityFailure.malformedRecord }

        let assistant: ClaudeAssistantEnvelope
        switch recordType {
        case "assistant":
            assistant = ClaudeAssistantEnvelope(
                timestamp: record.timestamp,
                isSidechain: record.isSidechain,
                message: record.message,
                requestIdentifier: record.requestIdentifier
            )
        case "progress":
            guard record.progress?.type?.nonemptyTrimmed == "agent_progress",
                  let nested = record.progress?.message,
                  nested.type.nonemptyTrimmed == "assistant"
            else { return }
            assistant = ClaudeAssistantEnvelope(
                timestamp: nested.timestamp ?? record.timestamp,
                isSidechain: nested.isSidechain ?? record.isSidechain,
                message: nested.message,
                requestIdentifier: nested.requestIdentifier
            )
        default:
            return
        }

        guard let message = assistant.message,
              let usage = message.usage,
              let messageID = message.identifier,
              let rawTimestamp = assistant.timestamp,
              let timestamp = LocalActivityTimestamp.date(rawTimestamp),
              let requestID = assistant.requestIdentifier
        else {
            throw ClaudeLocalActivityFailure.malformedUsage
        }

        events.append(ClaudeUsageEvent(
            messageID: messageID,
            requestID: requestID,
            timestamp: timestamp,
            timestampIdentity: rawTimestamp,
            lineOffset: line.startOffset,
            isSidechain: assistant.isSidechain ?? false,
            modelID: message.modelIdentifier,
            tokens: try ClaudeTokens(usage)
        ))
    }

    func finished(fingerprint: LocalActivityFileFingerprint, nextOffset: Int64) -> ParsedClaudeFile {
        ParsedClaudeFile(fingerprint: fingerprint, nextOffset: nextOffset, parserState: self)
    }
}

private struct ClaudeUsageEvent: Sendable {
    let messageID: String
    let requestID: String
    let timestamp: Date
    let timestampIdentity: String
    let lineOffset: Int64
    let isSidechain: Bool
    let modelID: String?
    let tokens: ClaudeTokens

    var orderingIdentity: String {
        LocalActivityIdentity.digest([
            "message", messageID,
            "request", requestID,
            "timestamp", timestampIdentity,
            "sidechain", String(isSidechain),
            "model", modelID ?? "",
            "input", String(tokens.input),
            "cache-creation", String(tokens.cacheCreation),
            "cache-read", String(tokens.cacheRead),
            "output", String(tokens.output),
        ])
    }
}

/// Claude reports its cache categories separately from input, so all four are
/// additive and every one of them must be present to trust the record.
private struct ClaudeTokens: Sendable, Equatable {
    let input: Int64
    let cacheCreation: Int64
    let cacheRead: Int64
    let output: Int64
    let total: Int64

    init(_ usage: ClaudeUsage) throws {
        guard let input = usage.inputTokens,
              let cacheCreation = usage.cacheCreationInputTokens,
              let cacheRead = usage.cacheReadInputTokens,
              let output = usage.outputTokens,
              input >= 0, cacheCreation >= 0, cacheRead >= 0, output >= 0
        else {
            throw ClaudeLocalActivityFailure.malformedUsage
        }

        func add(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
            let value = lhs.addingReportingOverflow(rhs)
            guard !value.overflow else { throw ClaudeLocalActivityFailure.arithmeticOverflow }
            return value.partialValue
        }

        self.input = input
        self.cacheCreation = cacheCreation
        self.cacheRead = cacheRead
        self.output = output
        total = try add(add(add(input, cacheCreation), cacheRead), output)
    }
}

/// Selective decoding. Conversation content, working directories, git branches,
/// project names, tool payloads, and session identifiers are deliberately absent
/// from these types, so they cannot reach published activity even by accident.
private struct ClaudeRecord: Decodable {
    let type: String
    let timestamp: String?
    let isSidechain: Bool?
    let message: ClaudeMessage?
    let progress: ClaudeAgentProgress?
    private let requestIDCamel: String?
    private let requestIDSnake: String?

    var requestIdentifier: String? {
        requestIDCamel?.nonemptyTrimmed ?? requestIDSnake?.nonemptyTrimmed
    }

    enum CodingKeys: String, CodingKey {
        case type, timestamp, isSidechain, message
        case progress = "data"
        case requestIDCamel = "requestId"
        case requestIDSnake = "request_id"
    }
}

private struct ClaudeAgentProgress: Decodable {
    let type: String?
    let message: ClaudeNestedRecord?
}

private struct ClaudeNestedRecord: Decodable {
    let type: String
    let timestamp: String?
    let isSidechain: Bool?
    let message: ClaudeMessage?
    private let requestIDCamel: String?
    private let requestIDSnake: String?

    var requestIdentifier: String? {
        requestIDCamel?.nonemptyTrimmed ?? requestIDSnake?.nonemptyTrimmed
    }

    enum CodingKeys: String, CodingKey {
        case type, timestamp, isSidechain, message
        case requestIDCamel = "requestId"
        case requestIDSnake = "request_id"
    }
}

private struct ClaudeAssistantEnvelope {
    let timestamp: String?
    let isSidechain: Bool?
    let message: ClaudeMessage?
    let requestIdentifier: String?
}

private struct ClaudeMessage: Decodable {
    let id: String?
    let model: String?
    let usage: ClaudeUsage?

    var identifier: String? { id?.nonemptyTrimmed }
    var modelIdentifier: String? { model?.nonemptyTrimmed }
}

private struct ClaudeUsage: Decodable {
    let inputTokens: Int64?
    let outputTokens: Int64?
    let cacheCreationInputTokens: Int64?
    let cacheReadInputTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

private extension String {
    var nonemptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
