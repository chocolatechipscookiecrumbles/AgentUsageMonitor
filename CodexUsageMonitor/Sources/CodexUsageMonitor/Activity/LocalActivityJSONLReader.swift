import Foundation

struct LocalActivityJSONLReader: Sendable {
    struct Line: Sendable {
        let bytes: Data
        let startOffset: Int64
        let endOffset: Int64
    }

    struct Result: Sendable {
        let lines: [Line]
        let nextOffset: Int64
    }

    private let chunkSize = 64 * 1024
    private let maximumLineSize = 8 * 1024 * 1024

    @concurrent
    func read(fileURL: URL, from offset: Int64 = 0) async throws -> Result {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, offset)))

        var lines: [Line] = []
        var buffer = Data()
        var lineStart = max(0, offset)
        var streamOffset = lineStart
        var nextOffset = lineStart
        var discardingOversizedLine = false

        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            var segmentStart = chunk.startIndex
            while segmentStart < chunk.endIndex {
                guard let newline = chunk[segmentStart...].firstIndex(of: 0x0A) else {
                    let segment = chunk[segmentStart...]
                    if !discardingOversizedLine {
                        if buffer.count + segment.count > maximumLineSize {
                            buffer.removeAll(keepingCapacity: false)
                            discardingOversizedLine = true
                        } else {
                            buffer.append(contentsOf: segment)
                        }
                    }
                    streamOffset += Int64(segment.count)
                    break
                }

                let segment = chunk[segmentStart..<newline]
                if !discardingOversizedLine {
                    if buffer.count + segment.count > maximumLineSize {
                        buffer.removeAll(keepingCapacity: false)
                        discardingOversizedLine = true
                    } else {
                        buffer.append(contentsOf: segment)
                    }
                }
                streamOffset += Int64(segment.count + 1)

                if !discardingOversizedLine {
                    if buffer.last == 0x0D {
                        buffer.removeLast()
                    }
                    lines.append(Line(bytes: buffer, startOffset: lineStart, endOffset: streamOffset))
                }

                buffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
                lineStart = streamOffset
                nextOffset = streamOffset
                segmentStart = chunk.index(after: newline)
            }
        }

        return Result(lines: lines, nextOffset: nextOffset)
    }
}
