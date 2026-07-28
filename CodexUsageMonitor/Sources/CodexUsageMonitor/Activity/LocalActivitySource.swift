import Foundation

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
