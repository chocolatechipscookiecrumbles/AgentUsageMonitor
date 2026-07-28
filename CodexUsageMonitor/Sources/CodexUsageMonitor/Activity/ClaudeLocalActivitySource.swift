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
struct ClaudeLocalActivitySource: LocalActivitySource {
    let provider: AgentProvider = .claudeCode

    private let projectRoots: [URL]
    private let traversal = LocalActivityFileTraversal()

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

            for root in projectRoots {
                let files: [ParsedClaudeFile]
                do {
                    files = try await traversal.parseJSONLFiles(
                        root: root,
                        makeState: { ClaudeFileParseState(opaqueFileID: $0) },
                        consume: { state, line in try state.consume(line) },
                        finish: { state, nextOffset in state.finished(nextOffset: nextOffset) }
                    )
                } catch LocalActivityFileTraversal.TraversalFailure.rootMissing {
                    continue
                }
                anyRootExists = true
                // Configured roots can resolve to the same directory, and the
                // same file must not be parsed twice under two cursors.
                parsedFiles.append(
                    contentsOf: files.filter { seenFileIDs.insert($0.opaqueFileID).inserted }
                )
            }

            guard anyRootExists, !parsedFiles.isEmpty else {
                return LocalActivityScanResult(requests: [], cursors: [], status: .localRecordsMissing)
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

    private func reconcile(
        _ files: [ParsedClaudeFile],
        priorOffsets: [String: Int64]
    ) throws -> [LocalActivityRequest] {
        // One assistant message is one request no matter how many chunks or
        // transcripts repeat it, so the message identity is the reconciliation
        // key both within and across files.
        var winners: [String: (file: ParsedClaudeFile, event: ClaudeUsageEvent)] = [:]
        for file in files {
            for event in file.events {
                guard let incumbent = winners[event.messageID] else {
                    winners[event.messageID] = (file, event)
                    continue
                }
                if Self.prefers(event, over: incumbent.event) {
                    winners[event.messageID] = (file, event)
                }
            }
        }

        var requests: [LocalActivityRequest] = []
        requests.reserveCapacity(winners.count)
        for (messageID, winner) in winners {
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
                // Anthropic message identifiers are unique per response, so
                // hashing the message alone keeps one stable published identity
                // across rescans no matter which copy of it wins.
                id: LocalActivityIdentity.digest(["provider", "claude-code", "message", messageID]),
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

private struct ParsedClaudeFile: Sendable {
    let opaqueFileID: String
    let nextOffset: Int64
    let events: [ClaudeUsageEvent]
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

        // Transcripts hold many record kinds. Only an assistant record carrying
        // a usage object claims tokens; everything else is ignorable rather than
        // missing evidence.
        guard recordType == "assistant",
              let message = record.message,
              let usage = message.usage
        else { return }

        guard let messageID = message.identifier,
              let rawTimestamp = record.timestamp,
              let timestamp = LocalActivityTimestamp.date(rawTimestamp),
              let requestID = record.requestIdentifier
        else {
            throw ClaudeLocalActivityFailure.malformedUsage
        }

        events.append(ClaudeUsageEvent(
            messageID: messageID,
            requestID: requestID,
            timestamp: timestamp,
            timestampIdentity: rawTimestamp,
            lineOffset: line.startOffset,
            isSidechain: record.isSidechain ?? false,
            modelID: message.modelIdentifier,
            tokens: try ClaudeTokens(usage)
        ))
    }

    func finished(nextOffset: Int64) -> ParsedClaudeFile {
        ParsedClaudeFile(opaqueFileID: opaqueFileID, nextOffset: nextOffset, events: events)
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
