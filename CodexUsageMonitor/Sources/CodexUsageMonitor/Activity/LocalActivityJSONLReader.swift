import Darwin
import Foundation

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
                    try consume(
                        &state,
                        Line(bytes: lineBuffer, startOffset: lineStart, endOffset: streamOffset)
                    )
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
