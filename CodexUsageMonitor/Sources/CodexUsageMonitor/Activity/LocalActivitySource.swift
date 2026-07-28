import CryptoKit
import Foundation

/// Framing shared by every source that publishes an opaque identity.
///
/// Fields are hashed with their count and byte lengths written first, so no
/// combination of field values can collide with a different field split. The
/// digest is what leaves the source; the source identifiers never do.
enum LocalActivityIdentity {
    static func digest(_ fields: [String]) -> String {
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
}

/// Provider records carry ISO-8601 timestamps with and without fractional
/// seconds, so both spellings must parse or whole scans silently accept nothing.
enum LocalActivityTimestamp {
    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return parsed
        }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value)
    }
}

/// Opaque incremental-read state. It deliberately has no path, URL, project,
/// session, or provider error that could escape into published activity state.
struct LocalActivityFileCursor: Sendable, Equatable {
    let opaqueFileID: String
    let nextByteOffset: Int64
}

struct LocalActivityScanBounds: Sendable, Equatable {
    let cursors: [LocalActivityFileCursor]

    init(cursors: [LocalActivityFileCursor] = []) {
        self.cursors = cursors
    }
}

enum LocalActivitySourceStatus: Sendable, Equatable {
    case readable
    case localRecordsMissing
    case unsafeToRead
}

/// Sanitized output of one provider scan. Reconciled requests contain only the
/// display-safe fields in `LocalActivityRequest`; source-specific details stay
/// inside the implementation that performed the read.
struct LocalActivityScanResult: Sendable, Equatable {
    let requests: [LocalActivityRequest]
    let cursors: [LocalActivityFileCursor]
    let status: LocalActivitySourceStatus
}

protocol LocalActivitySource: Sendable {
    var provider: AgentProvider { get }

    func scan(bounds: LocalActivityScanBounds) async -> LocalActivityScanResult
}
