import Foundation

/// The default location the app reads: an owner-only file under Application
/// Support. Kept identical to the former Python bridge and the app's reader.
public func defaultOutputPath() -> URL {
    let support = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    return support
        .appendingPathComponent("CodexUsageMonitor", isDirectory: true)
        .appendingPathComponent("claude-rate-limits.json")
}

/// Atomically writes the snapshot with owner-only directory and file
/// permissions. The write goes to a temp file in the same directory and is then
/// renamed over the target, so a reader never sees a partial file.
public func writeSnapshot(_ snapshot: RateLimitSnapshot, to outputPath: URL) throws {
    let directory = outputPath.deletingLastPathComponent()
    let fileManager = FileManager.default

    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

    let data = try JSONSerialization.data(
        withJSONObject: snapshot.jsonObject,
        options: [.sortedKeys]
    )

    let tempURL = directory.appendingPathComponent(".claude-rate-limits-\(UUID().uuidString).tmp")
    do {
        try data.write(to: tempURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
        // POSIX rename overwrites atomically and creates the target when absent
        // (first run), matching the previous bridge's `os.replace`. FileManager's
        // replaceItemAt is unreliable when the destination does not yet exist.
        guard rename(tempURL.path, outputPath.path) == 0 else {
            throw SnapshotWriteError.renameFailed(errno: errno)
        }
    } catch {
        try? fileManager.removeItem(at: tempURL)
        throw error
    }
}

public enum SnapshotWriteError: Error, Equatable {
    case renameFailed(errno: Int32)
}
