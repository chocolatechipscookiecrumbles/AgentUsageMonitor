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
struct LocalActivityFileTraversal: Sendable {
    enum TraversalFailure: Error {
        case rootMissing
        case unsafeFilesystem
    }

    private let reader = LocalActivityJSONLReader()

    /// Parses every regular `.jsonl` file below `root`, newest-agnostic and in
    /// filesystem order. Paths stay inside this call; callers receive only the
    /// opaque device/inode file ID used to identify cached scan state.
    func parseJSONLFiles<State: Sendable, Parsed: Sendable>(
        root: URL,
        makeState: @Sendable (String) -> State,
        consume: @Sendable (inout State, LocalActivityJSONLReader.Line) throws -> Void,
        finish: @Sendable (State, Int64) -> Parsed
    ) async throws -> [Parsed] {
        let rootDescriptor = try Self.openRootDirectory(root)
        defer { _ = Darwin.close(rootDescriptor) }
        return try await parse(
            directoryDescriptor: rootDescriptor,
            seenFileIDs: [],
            makeState: makeState,
            consume: consume,
            finish: finish
        ).parsed
    }

    private func parse<State: Sendable, Parsed: Sendable>(
        directoryDescriptor: Int32,
        seenFileIDs: Set<String>,
        makeState: @Sendable (String) -> State,
        consume: @Sendable (inout State, LocalActivityJSONLReader.Line) throws -> Void,
        finish: @Sendable (State, Int64) -> Parsed
    ) async throws -> (parsed: [Parsed], seenFileIDs: Set<String>) {
        let duplicate = dup(directoryDescriptor)
        guard duplicate >= 0, let directory = fdopendir(duplicate) else {
            if duplicate >= 0 { _ = Darwin.close(duplicate) }
            throw TraversalFailure.unsafeFilesystem
        }
        defer { closedir(directory) }

        var parsed: [Parsed] = []
        var seenFileIDs = seenFileIDs

        while true {
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
                        makeState: makeState,
                        consume: consume,
                        finish: finish
                    )
                    parsed.append(contentsOf: nested.parsed)
                    seenFileIDs = nested.seenFileIDs

                case S_IFREG:
                    guard name.lowercased().hasSuffix(".jsonl") else { break }
                    let fileID = Self.opaqueFileID(device: childStat.st_dev, inode: childStat.st_ino)
                    guard seenFileIDs.insert(fileID).inserted else { break }
                    let result = try await reader.read(
                        fileDescriptor: childDescriptor,
                        initialState: makeState(fileID),
                        consume: consume
                    )
                    parsed.append(finish(result.state, result.nextOffset))

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

        return (parsed, seenFileIDs)
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
            let byteCount = Darwin.read(fileDescriptor, &chunk, chunk.count)
            if byteCount < 0 {
                if errno == EINTR { continue }
                throw ReaderFailure.readFailed
            }
            if byteCount == 0 { break }

            var segmentStart = 0
            let count = Int(byteCount)
            while segmentStart < count {
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
