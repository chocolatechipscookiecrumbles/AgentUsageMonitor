import Foundation

enum ClaudeStatusLineInstallResult: Equatable {
    case installed
    case alreadyInstalled
    case existingCustomStatusLineFound
    case unableToUpdateSettings
}

/// Why a configured status line can be replaced. Both cases mean the command
/// is already broken, so repairing it takes nothing away from the user.
enum ClaudeStatusLineRepairReason: Equatable {
    /// A command this project installed in an earlier version.
    case supersededProjectBridge
    /// The command names an absolute path that no longer exists, so it cannot
    /// be producing a status line for anyone.
    case brokenPath
}

/// What `~/.claude/settings.json` currently says, without changing it.
enum ClaudeStatusLineState: Equatable {
    case notConfigured
    case installed
    case repairable(existing: String, reason: ClaudeStatusLineRepairReason)
    /// Someone else's working status line. Never replaced.
    case foreign(existing: String)
    case settingsUnreadable
}

/// Whether passive capture is actually producing anything, phrased for the UI.
///
/// The tier was dead in production while the app said nothing about it, so a
/// missing snapshot has to read as a state with an action, not as silence.
struct ClaudePassiveCaptureHealth: Equatable {
    let state: ClaudeStatusLineState
    let lastCapturedAt: Date?
    private let now: Date

    init(state: ClaudeStatusLineState, lastCapturedAt: Date?, now: Date = .now) {
        self.state = state
        self.lastCapturedAt = lastCapturedAt
        self.now = now
    }

    /// Installed *and* actually producing snapshots. Installation alone is not
    /// health: the superseded bridge was "configured" for weeks and captured
    /// nothing.
    var isHealthy: Bool {
        guard state == .installed else { return false }
        return lastCapturedAt != nil
    }

    var summary: String {
        switch state {
        case .notConfigured:
            return "Not set up. Claude Code can write usage to a file this app reads, at no token cost."
        case .settingsUnreadable:
            return "Claude Code's settings file could not be read, so passive capture cannot be configured."
        case .foreign:
            return "Claude Code already has a custom status line. Agent Monitor will not change it."
        case .repairable(_, let reason):
            switch reason {
            case .supersededProjectBridge:
                return "Claude Code is still pointed at an older Agent Monitor helper that no longer exists, "
                    + "so no usage is being captured."
            case .brokenPath:
                return "Claude Code's status line points at a program that no longer exists, "
                    + "so no usage is being captured."
            }
        case .installed:
            guard let lastCapturedAt else {
                return "Set up, but Claude Code has never written a reading yet. It writes one on its next turn."
            }
            return "Last reading captured \(RelativeTimeText.text(from: lastCapturedAt, to: now))."
        }
    }

    var repairActionTitle: String? {
        switch state {
        case .repairable: return "Repair"
        case .notConfigured: return "Set Up"
        case .installed, .foreign, .settingsUnreadable: return nil
        }
    }
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

    /// Markers identifying a status-line command **this project** installed at
    /// some point. The superseded Python bridge is the reason this exists: on
    /// the reporting machine the configured command was this project's own
    /// earlier helper pointing at a directory that had since been deleted, and
    /// treating it as the user's custom status line meant the capture stayed
    /// dead and unrepairable forever.
    private static let projectBridgeMarkers = ["claude-usage-bridge", "claude_usage_bridge"]

    /// Classifies the existing status line without changing anything.
    func inspect(fileManager: FileManager = .default) -> ClaudeStatusLineState {
        guard fileManager.fileExists(atPath: settingsURL.path) else { return .notConfigured }
        guard let data = try? Data(contentsOf: settingsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .settingsUnreadable }

        guard let statusLine = root["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String
        else { return .notConfigured }

        if command == bridgeCommand { return .installed }

        if Self.projectBridgeMarkers.contains(where: command.contains) {
            return .repairable(existing: command, reason: .supersededProjectBridge)
        }
        if let path = Self.firstReferencedPath(in: command),
           !fileManager.fileExists(atPath: path) {
            return .repairable(existing: command, reason: .brokenPath)
        }
        return .foreign(existing: command)
    }

    /// The first absolute path the command names — the `cd` target or the
    /// executable. Only that one is checked: a later argument that happens to
    /// look like a path may legitimately not exist yet, and misreading one as a
    /// broken status line would offer to replace a working third-party setup.
    static func firstReferencedPath(in command: String) -> String? {
        if let open = command.firstIndex(of: "'"),
           let close = command[command.index(after: open)...].firstIndex(of: "'") {
            let quoted = String(command[command.index(after: open)..<close])
            if quoted.hasPrefix("/") { return quoted }
        }
        for token in command.split(separator: " ") where token.hasPrefix("/") {
            return String(token)
        }
        return nil
    }

    /// `replacingExisting` is the explicit confirmation gate. Without it a
    /// repairable command is reported, never overwritten — the user has to be
    /// shown what changes before their Claude Code configuration is edited.
    func install(replacingExisting: Bool = false) -> ClaudeStatusLineInstallResult {
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            guard let data = try? Data(contentsOf: settingsURL),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return .unableToUpdateSettings }
            root = parsed
        }

        switch inspect() {
        case .installed:
            return .alreadyInstalled
        case .settingsUnreadable:
            return .unableToUpdateSettings
        case .foreign:
            // A working third-party status line is never replaced, with or
            // without confirmation.
            return .existingCustomStatusLineFound
        case .repairable:
            guard replacingExisting else { return .existingCustomStatusLineFound }
        case .notConfigured:
            break
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
