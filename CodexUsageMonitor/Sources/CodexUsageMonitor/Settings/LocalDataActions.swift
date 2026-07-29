import AppKit
import Foundation
import UniformTypeIdentifiers

/// The actions Data & Privacy offers over the app's own local storage.
///
/// Everything here is scoped to the files `LocalDataInventory` already
/// documents. Claude Code's Keychain item and the records the agents own are
/// deliberately out of reach: this app does not store them, so it has nothing
/// to reveal or export.
@MainActor
enum LocalDataActions {
    static var directoryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("CodexUsageMonitor")
    }

    /// Opens the folder in Finder. Falls back to the parent when the folder
    /// does not exist yet, which is the normal state before the first refresh.
    static func revealInFinder() {
        let directory = directoryURL
        if FileManager.default.fileExists(atPath: directory.path) {
            NSWorkspace.shared.activateFileViewerSelecting([directory])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([directory.deletingLastPathComponent()])
        }
    }

    /// Selects one file in Finder, or its folder when the file has not been
    /// written yet.
    static func revealFile(named fileName: String) {
        let file = directoryURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } else {
            revealInFinder()
        }
    }

    static func copyDirectoryPath() {
        copyToPasteboard(LocalDataInventory.directory)
    }

    static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: Export

    static func suggestedExportFileName(now: Date = .now) -> String {
        let day = now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "CodexUsageMonitor-local-data-\(day).json"
    }

    /// Runs the save panel and writes the snapshot. Returns the chosen URL, or
    /// `nil` when the user cancels.
    @discardableResult
    static func runExportPanel(now: Date = .now) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Local Data"
        panel.nameFieldStringValue = suggestedExportFileName(now: now)
        panel.allowedContentTypes = [.json]
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try exportSnapshot(to: url, now: now)
        return url
    }

    static func exportSnapshot(to url: URL, now: Date = .now) throws {
        try snapshotData(now: now).write(to: url, options: .atomic)
    }

    /// One JSON document holding every app-owned store, plus enough context to
    /// read it later. A store that is missing or unreadable is recorded as
    /// such rather than omitted, so an export never overstates what it captured.
    static func snapshotData(now: Date = .now, bundle: Bundle = .main) throws -> Data {
        var files: [String: Any] = [:]
        for store in LocalDataInventory.stores {
            files[store.fileName] = fileEntry(for: store)
        }

        let snapshot: [String: Any] = [
            "exportedAt": now.formatted(.iso8601),
            "application": [
                "name": "Agent Monitor",
                "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
                "build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local",
            ],
            "directory": LocalDataInventory.directory,
            "files": files,
        ]
        return try JSONSerialization.data(
            withJSONObject: snapshot,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func fileEntry(for store: LocalDataStoreDescriptor) -> [String: Any] {
        var entry: [String: Any] = [
            "title": store.title,
            "retention": store.retention,
            "contents": store.contents,
        ]
        let url = directoryURL.appendingPathComponent(store.fileName)
        guard let data = try? Data(contentsOf: url) else {
            entry["status"] = "not written on this Mac"
            return entry
        }
        guard let decoded = try? JSONSerialization.jsonObject(with: data) else {
            entry["status"] = "present but not readable as JSON"
            return entry
        }
        entry["status"] = "exported"
        entry["data"] = decoded
        return entry
    }
}
