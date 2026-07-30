import Foundation
import XCTest
@testable import CodexUsageMonitor

@MainActor
final class LocalDataActionsRegressionTests: XCTestCase {
    func testExportRejectsInventoryFileSymlink() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let ownerDirectory = root.appendingPathComponent("owner", isDirectory: true)
        let outsideFile = root.appendingPathComponent("outside.json")
        try FileManager.default.createDirectory(
            at: ownerDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        try #"{"secret":"must not be exported"}"#.write(
            to: outsideFile,
            atomically: true,
            encoding: .utf8
        )
        let inventoryName = try XCTUnwrap(LocalDataInventory.stores.first?.fileName)
        try FileManager.default.createSymbolicLink(
            at: ownerDirectory.appendingPathComponent(inventoryName),
            withDestinationURL: outsideFile
        )

        let data = try LocalDataActions.snapshotData(
            now: Date(timeIntervalSince1970: 1_700_000_000),
            directoryURL: ownerDirectory
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let files = try XCTUnwrap(object["files"] as? [String: Any])
        let entry = try XCTUnwrap(files[inventoryName] as? [String: Any])

        XCTAssertEqual(entry["status"] as? String, "present but not safely readable")
        XCTAssertNil(entry["data"])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("must not be exported"))
    }
}
