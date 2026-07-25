import Foundation

enum ClaudeStatusLineInstallResult: Equatable {
    case installed
    case alreadyInstalled
    case existingCustomStatusLineFound
    case unableToUpdateSettings
}

/// Merges a statusLine entry pointing at the native Claude usage bridge into
/// ~/.claude/settings.json, without ever touching an unrelated existing
/// statusLine or a file that fails to parse as JSON.
struct ClaudeStatusLineInstaller {
    static let bridgeExecutableName = "claude-usage-bridge"

    private let settingsURL: URL
    private let bridgeCommand: String

    /// Production path: copy the signed bundle's read-only bridge executable to
    /// app-owned Application Support before pointing Claude Code at it.
    ///
    /// Copying (rather than pointing into the .app) does two things: it strips
    /// the quarantine flag so Claude Code can exec the helper without a Gatekeeper
    /// block, and it keeps the statusLine command stable across app-bundle
    /// replacement.
    init?(
        settingsURL: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json"),
        bundledBridgeDirectory: URL? = Bundle.main.resourceURL?
            .appendingPathComponent("ClaudeUsageBridge"),
        applicationSupportDirectory: URL? = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
        fileManager: FileManager = .default
    ) {
        guard let bundledBridgeDirectory,
              let applicationSupportDirectory,
              fileManager.fileExists(
                  atPath: bundledBridgeDirectory
                      .appendingPathComponent(Self.bridgeExecutableName)
                      .path
              ),
              let bridgeDirectory = try? Self.prepareBridgeDirectory(
                  bundledBridgeDirectory: bundledBridgeDirectory,
                  applicationSupportDirectory: applicationSupportDirectory,
                  fileManager: fileManager
              )
        else { return nil }
        self.init(
            settingsURL: settingsURL,
            bridgeExecutable: bridgeDirectory.appendingPathComponent(Self.bridgeExecutableName)
        )
    }

    init(settingsURL: URL, bridgeExecutable: URL) {
        self.settingsURL = settingsURL
        self.bridgeCommand = "\(Self.shellQuoted(bridgeExecutable.path)) --quiet"
    }

    static func prepareBridgeDirectory(
        bundledBridgeDirectory: URL,
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let parentDirectory = applicationSupportDirectory
            .appendingPathComponent("CodexUsageMonitor", isDirectory: true)
        let destination = parentDirectory
            .appendingPathComponent("ClaudeBridge", isDirectory: true)
        let staging = parentDirectory
            .appendingPathComponent(".ClaudeBridge-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: parentDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: parentDirectory.path
        )
        try fileManager.copyItem(at: bundledBridgeDirectory, to: staging)
        defer { try? fileManager.removeItem(at: staging) }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: staging,
                backupItemName: nil
            )
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }

        // The copied helper must be executable and free of the quarantine flag
        // so Claude Code can exec it directly. Both are best-effort: a missing
        // quarantine attribute is the normal case and not an error.
        let executable = destination.appendingPathComponent(bridgeExecutableName)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        removeQuarantine(executable)
        return destination
    }

    /// Best-effort removal of `com.apple.quarantine` from a copied executable.
    private static func removeQuarantine(_ url: URL) {
        _ = url.withUnsafeFileSystemRepresentation { path in
            path.map { removexattr($0, "com.apple.quarantine", 0) }
        }
    }

    /// Single-quotes a path for safe use inside the shell command Claude
    /// Code's statusLine executes. Without this, a path containing a space
    /// (e.g. a directory literally named "agent usage") splits into multiple
    /// shell words and the command fails.
    private static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func install() -> ClaudeStatusLineInstallResult {
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            guard let data = try? Data(contentsOf: settingsURL),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return .unableToUpdateSettings }
            root = parsed
        }

        if let existingStatusLine = root["statusLine"] as? [String: Any] {
            if existingStatusLine["command"] as? String == bridgeCommand {
                return .alreadyInstalled
            }
            return .existingCustomStatusLineFound
        }

        root["statusLine"] = ["type": "command", "command": bridgeCommand]

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return .unableToUpdateSettings
        }
        do {
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            return .unableToUpdateSettings
        }
        return .installed
    }
}
