import CryptoKit
import Darwin
import Foundation

/// Descriptor-relative traversal of a provider-owned records root.
///
/// It refuses symbolic links in every root ancestor and at every recursively
/// opened target, and it reads each regular `.jsonl` file immediately so no
/// more than one file descriptor per directory depth stays open. Session roots
/// grow without bound, so collecting descriptors first would eventually exhaust
/// the process file-descriptor limit and make activity permanently unreadable.
/// Identity and change evidence for one provider-owned records file.
///
/// The identity is an opaque device/inode digest, so nothing derived from a
/// path leaves the traversal. Size and modification time are what let a caller
/// decide that a file needs no work at all.
struct LocalActivityFileFingerprint: Sendable, Equatable, Hashable {
    let opaqueFileID: String
    let byteSize: Int64
    let modifiedAtSeconds: Int64
    let modifiedAtNanoseconds: Int64
    /// Hash of this complete file version. It never leaves the source cache and
    /// lets a later growth verify every byte of the previously parsed prefix.
    let contentDigest: String

    func hasSameMetadata(as other: Self) -> Bool {
        opaqueFileID == other.opaqueFileID
            && byteSize == other.byteSize
            && modifiedAtSeconds == other.modifiedAtSeconds
            && modifiedAtNanoseconds == other.modifiedAtNanoseconds
    }
}

/// How much of a file a caller already holds parsed.
enum LocalActivityResumePoint<State: Sendable, Parsed: Sendable>: Sendable {
    /// Nothing changed; reuse the previous result without opening the file.
    case unchanged(Parsed)
    /// Appended bytes only; continue from this parser state and byte offset.
    case resume(State, offset: Int64)
    /// Truncated, replaced, or never seen; parse from the beginning.
    case rebuild
}

/// A file a source parsed on an earlier scan and may be able to reuse.
protocol LocalActivityParsedFile: Sendable {
    associatedtype ParserState: Sendable

    var fingerprint: LocalActivityFileFingerprint { get }
    /// Byte offset just past the last complete line, so a partial trailing
    /// record is read again once the provider finishes writing it.
    var nextOffset: Int64 { get }
    var parserState: ParserState { get }
}

extension LocalActivityResumePoint where Parsed: LocalActivityParsedFile, Parsed.ParserState == State {
    /// Picks the cheapest safe way to bring a cached file up to date.
    static func decide(
        fingerprint: LocalActivityFileFingerprint,
        cached: Parsed?,
        fileDescriptor: Int32
    ) -> Self {
        guard let cached else { return .rebuild }
        if cached.fingerprint.hasSameMetadata(as: fingerprint) {
            return .unchanged(cached)
        }
        // Only growth beyond the bytes already parsed can be a pure append.
        // Anything shorter may have rewritten records that were already
        // counted, and resuming past the end would silently read nothing.
        // A changed file at exactly the same size was rewritten in place, not
        // appended. Rebuild it so an editor/provider rewrite cannot leave the
        // old parsed requests resident for the rest of this process.
        guard fingerprint.byteSize > cached.fingerprint.byteSize,
              cached.nextOffset == cached.fingerprint.byteSize,
              !cached.fingerprint.contentDigest.isEmpty,
              let currentPrefixDigest = try? LocalActivityFileContentDigest.digest(
                  fileDescriptor: fileDescriptor,
                  byteCount: cached.fingerprint.byteSize
              ),
              currentPrefixDigest == cached.fingerprint.contentDigest
        else { return .rebuild }
        return .resume(cached.parserState, offset: cached.nextOffset)
    }
}

struct LocalActivityFileTraversal: Sendable {
    enum TraversalFailure: Error {
        case rootMissing
        case unsafeFilesystem
    }

    private let reader = LocalActivityJSONLReader()

    /// Parses every regular `.jsonl` file below `root` in filesystem order.
    /// Paths stay inside this call; callers receive only the opaque file ID.
    ///
    /// `resume` decides per file whether to skip it, continue from a cached
    /// parser state, or rebuild it. Provider roots hold months of transcripts,
    /// so decoding every line on every file event would dominate the cost of
    /// a single appended record.
    func parseJSONLFiles<State: Sendable, Parsed: Sendable>(
        root: URL,
        resume: @Sendable (
            LocalActivityFileFingerprint,
            Int32
        ) -> LocalActivityResumePoint<State, Parsed>,
        makeState: @Sendable (String) -> State,
        consume: @Sendable (inout State, LocalActivityJSONLReader.Line) throws -> Void,
        finish: @Sendable (LocalActivityFileFingerprint, State, Int64) -> Parsed
    ) async throws -> Outcome<Parsed> {
        try Task.checkCancellation()
        let rootDescriptor = try Self.openRootDirectory(root)
        defer { _ = Darwin.close(rootDescriptor) }
        let result = try await parse(
            directoryDescriptor: rootDescriptor,
            seenFileIDs: [],
            resume: resume,
            makeState: makeState,
            consume: consume,
            finish: finish
        )
        return Outcome(parsed: result.parsed, skippedFileCount: result.skippedFileCount)
    }

    /// What a traversal found, and what it could not interpret.
    ///
    /// `skippedFileCount` exists so a caller can tell "this root has nothing in
    /// it" from "this root has nothing this build could read" — collapsing those
    /// would let a wholly unreadable root present as an empty one.
    struct Outcome<Parsed: Sendable>: Sendable {
        let parsed: [Parsed]
        let skippedFileCount: Int
    }

    private func parse<State: Sendable, Parsed: Sendable>(
        directoryDescriptor: Int32,
        seenFileIDs: Set<String>,
        resume: @Sendable (
            LocalActivityFileFingerprint,
            Int32
        ) -> LocalActivityResumePoint<State, Parsed>,
        makeState: @Sendable (String) -> State,
        consume: @Sendable (inout State, LocalActivityJSONLReader.Line) throws -> Void,
        finish: @Sendable (LocalActivityFileFingerprint, State, Int64) -> Parsed
    ) async throws -> (parsed: [Parsed], seenFileIDs: Set<String>, skippedFileCount: Int) {
        try Task.checkCancellation()
        let duplicate = dup(directoryDescriptor)
        guard duplicate >= 0, let directory = fdopendir(duplicate) else {
            if duplicate >= 0 { _ = Darwin.close(duplicate) }
            throw TraversalFailure.unsafeFilesystem
        }
        defer { closedir(directory) }

        var parsed: [Parsed] = []
        var seenFileIDs = seenFileIDs
        var skippedFileCount = 0

        while true {
            try Task.checkCancellation()
            // `readdir` reports end-of-directory and failure the same way, so
            // errno must be cleared immediately before every call rather than
            // once per successful iteration.
            errno = 0
            guard let entry = readdir(directory) else { break }
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(NAME_MAX) + 1) {
                    String(cString: $0)
                }
            }
            guard !name.hasPrefix(".") else { continue }

            let childDescriptor = name.withCString {
                openat(directoryDescriptor, $0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            }
            guard childDescriptor >= 0 else { throw TraversalFailure.unsafeFilesystem }

            var childStat = stat()
            guard fstat(childDescriptor, &childStat) == 0 else {
                _ = Darwin.close(childDescriptor)
                throw TraversalFailure.unsafeFilesystem
            }

            do {
                switch childStat.st_mode & S_IFMT {
                case S_IFDIR:
                    let nested = try await parse(
                        directoryDescriptor: childDescriptor,
                        seenFileIDs: seenFileIDs,
                        resume: resume,
                        makeState: makeState,
                        consume: consume,
                        finish: finish
                    )
                    parsed.append(contentsOf: nested.parsed)
                    seenFileIDs = nested.seenFileIDs
                    skippedFileCount += nested.skippedFileCount

                case S_IFREG:
                    guard name.lowercased().hasSuffix(".jsonl") else { break }
                    let fileID = Self.opaqueFileID(device: childStat.st_dev, inode: childStat.st_ino)
                    guard seenFileIDs.insert(fileID).inserted else { break }
                    let fingerprint = LocalActivityFileFingerprint(
                        opaqueFileID: fileID,
                        byteSize: Int64(childStat.st_size),
                        modifiedAtSeconds: Int64(childStat.st_mtimespec.tv_sec),
                        modifiedAtNanoseconds: Int64(childStat.st_mtimespec.tv_nsec),
                        contentDigest: ""
                    )

                    let start: (state: State, offset: Int64)?
                    switch resume(fingerprint, childDescriptor) {
                    case .unchanged(let previous):
                        parsed.append(previous)
                        start = nil
                    case .resume(let state, let offset):
                        start = (state, offset)
                    case .rebuild:
                        start = (makeState(fileID), 0)
                    }

                    if let start {
                        // One transcript this build cannot interpret must not
                        // erase every transcript it can. Before this, a single
                        // unreadable record anywhere under the root propagated
                        // out of the whole scan and blanked the card.
                        //
                        // Only *interpretation* failures are isolated.
                        // Cancellation and I/O failures still propagate: those
                        // say something about the read itself, not about one
                        // file's contents, and swallowing them would report a
                        // partial root as a complete one.
                        let result: LocalActivityJSONLReader.Result<State>
                        do {
                            result = try await reader.read(
                                fileDescriptor: childDescriptor,
                                from: start.offset,
                                initialState: start.state,
                                consume: consume
                            )
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch let error as LocalActivityJSONLReader.ReaderFailure {
                            throw error
                        } catch {
                            skippedFileCount += 1
                            break
                        }
                        try Task.checkCancellation()
                        let completedFingerprint = LocalActivityFileFingerprint(
                            opaqueFileID: fingerprint.opaqueFileID,
                            byteSize: fingerprint.byteSize,
                            modifiedAtSeconds: fingerprint.modifiedAtSeconds,
                            modifiedAtNanoseconds: fingerprint.modifiedAtNanoseconds,
                            contentDigest: try LocalActivityFileContentDigest.digest(
                                fileDescriptor: childDescriptor,
                                byteCount: fingerprint.byteSize
                            )
                        )
                        parsed.append(
                            finish(completedFingerprint, result.state, result.nextOffset)
                        )
                    }

                default:
                    break
                }
            } catch {
                _ = Darwin.close(childDescriptor)
                throw error
            }
            _ = Darwin.close(childDescriptor)
        }
        guard errno == 0 else { throw TraversalFailure.unsafeFilesystem }

        return (parsed, seenFileIDs, skippedFileCount)
    }

    /// Walks the root one component at a time so no ancestor symlink is
    /// followed, and returns the validated directory descriptor.
    private static func openRootDirectory(_ root: URL) throws -> Int32 {
        guard root.path.hasPrefix("/") else { throw TraversalFailure.unsafeFilesystem }
        let flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        var currentDescriptor = Darwin.open("/", flags)
        guard currentDescriptor >= 0 else { throw TraversalFailure.unsafeFilesystem }

        do {
            for component in root.path.split(separator: "/", omittingEmptySubsequences: true) {
                let name = String(component)
                guard name != ".", name != ".." else { throw TraversalFailure.unsafeFilesystem }
                let nextDescriptor = name.withCString { openat(currentDescriptor, $0, flags) }
                if nextDescriptor < 0 {
                    if errno == ENOENT { throw TraversalFailure.rootMissing }
                    throw TraversalFailure.unsafeFilesystem
                }
                _ = Darwin.close(currentDescriptor)
                currentDescriptor = nextDescriptor
            }

            var rootStat = stat()
            guard fstat(currentDescriptor, &rootStat) == 0,
                  rootStat.st_mode & S_IFMT == S_IFDIR
            else { throw TraversalFailure.unsafeFilesystem }
            return currentDescriptor
        } catch {
            _ = Darwin.close(currentDescriptor)
            throw error
        }
    }

    private static func opaqueFileID(device: dev_t, inode: ino_t) -> String {
        LocalActivityIdentity.digest(["device", String(device), "inode", String(inode)])
    }
}

struct LocalActivityJSONLReader: Sendable {
    struct Line: Sendable {
        let bytes: Data
        let startOffset: Int64
        let endOffset: Int64
    }

    struct Result<State: Sendable>: Sendable {
        let state: State
        let nextOffset: Int64
    }

    enum ReaderFailure: Error {
        case invalidOffset
        case offsetOverflow
        case readFailed
    }

    private let chunkSize = 64 * 1024
    private let maximumLineSize = 8 * 1024 * 1024

    /// Reads a descriptor opened and validated by the source. Completed lines
    /// are consumed immediately; raw bytes never accumulate beyond the current
    /// bounded line and read chunk.
    @concurrent
    func read<State: Sendable>(
        fileDescriptor: Int32,
        from offset: Int64 = 0,
        initialState: State,
        consume: @Sendable (inout State, Line) throws -> Void
    ) async throws -> Result<State> {
        try Task.checkCancellation()
        guard offset >= 0, lseek(fileDescriptor, offset, SEEK_SET) == offset else {
            throw ReaderFailure.invalidOffset
        }

        var state = initialState
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        var lineBuffer = Data()
        var lineStart = offset
        var streamOffset = offset
        var nextOffset = offset
        var discardingOversizedLine = false

        while true {
            try Task.checkCancellation()
            let byteCount = Darwin.read(fileDescriptor, &chunk, chunk.count)
            if byteCount < 0 {
                if errno == EINTR { continue }
                throw ReaderFailure.readFailed
            }
            if byteCount == 0 { break }

            var segmentStart = 0
            let count = Int(byteCount)
            while segmentStart < count {
                try Task.checkCancellation()
                let newline = chunk[segmentStart..<count].firstIndex(of: 0x0A)
                let segmentEnd = newline ?? count
                let segmentCount = segmentEnd - segmentStart

                if !discardingOversizedLine {
                    if lineBuffer.count + segmentCount > maximumLineSize {
                        lineBuffer.removeAll(keepingCapacity: false)
                        discardingOversizedLine = true
                    } else if segmentCount > 0 {
                        lineBuffer.append(contentsOf: chunk[segmentStart..<segmentEnd])
                    }
                }

                let consumedCount = segmentCount + (newline == nil ? 0 : 1)
                let advanced = streamOffset.addingReportingOverflow(Int64(consumedCount))
                guard !advanced.overflow else { throw ReaderFailure.offsetOverflow }
                streamOffset = advanced.partialValue

                guard newline != nil else { break }
                if !discardingOversizedLine {
                    if lineBuffer.last == 0x0D {
                        lineBuffer.removeLast()
                    }
                    // A blank line carries no record, so it must not reach a
                    // source that treats an undecodable line as unsafe evidence.
                    if !lineBuffer.isEmpty {
                        try consume(
                            &state,
                            Line(bytes: lineBuffer, startOffset: lineStart, endOffset: streamOffset)
                        )
                        try Task.checkCancellation()
                    }
                }

                lineBuffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
                lineStart = streamOffset
                nextOffset = streamOffset
                segmentStart = segmentEnd + 1
            }
        }

        return Result(state: state, nextOffset: nextOffset)
    }
}

private enum LocalActivityFileContentDigest {
    private static let chunkSize = 64 * 1024

    enum Failure: Error {
        case invalidSize
        case readFailed
    }

    static func digest(fileDescriptor: Int32, byteCount: Int64) throws -> String {
        guard byteCount >= 0 else { throw Failure.invalidSize }

        var hasher = SHA256()
        var bytes = [UInt8](repeating: 0, count: chunkSize)
        var offset: Int64 = 0
        while offset < byteCount {
            try Task.checkCancellation()
            let requested = Int(min(Int64(chunkSize), byteCount - offset))
            let readCount = bytes.withUnsafeMutableBytes { buffer in
                pread(fileDescriptor, buffer.baseAddress, requested, offset)
            }
            if readCount < 0 {
                if errno == EINTR { continue }
                throw Failure.readFailed
            }
            guard readCount > 0 else { throw Failure.readFailed }
            hasher.update(data: Data(bytes[0..<readCount]))
            offset += Int64(readCount)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
