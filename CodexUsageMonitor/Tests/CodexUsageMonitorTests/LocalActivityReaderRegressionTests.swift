import Foundation
import XCTest
@testable import CodexUsageMonitor

final class LocalActivityReaderRegressionTests: XCTestCase {
    func testCancellationStopsBeforeTheNextRecordIsConsumed() async throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("records.jsonl")
        try (Array(repeating: #"{"record":true}"#, count: 100).joined(separator: "\n") + "\n")
            .write(to: fileURL, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let firstRecordStarted = AsyncSignal()
        let releaseFirstRecord = DispatchSemaphore(value: 0)
        let consumed = LockedCounter()
        let task = Task {
            try await LocalActivityJSONLReader().read(
                fileDescriptor: handle.fileDescriptor,
                initialState: 0
            ) { state, _ in
                state += 1
                consumed.increment()
                if state == 1 {
                    firstRecordStarted.signal()
                    releaseFirstRecord.wait()
                }
            }
        }

        await firstRecordStarted.wait()
        task.cancel()
        releaseFirstRecord.signal()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to stop the read")
        } catch is CancellationError {
            // Expected.
        }
        XCTAssertEqual(consumed.value, 1)
    }
}

private final class AsyncSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var signaled = false

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                if signaled {
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }
    }

    func signal() {
        let continuation = lock.withLock {
            signaled = true
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        continuation?.resume()
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
