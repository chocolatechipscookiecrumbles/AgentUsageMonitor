import Darwin
import Foundation
import Security

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
    private static let managedDefaultsKey = "claude.passive-capture-managed.v1"

    private let settingsURL: URL
    private let bridgeExecutable: URL
    private let bridgeCommand: String
    private let managedDefaults: UserDefaults?

    /// Production path: create an app-owned symlink to this app's signed Mach-O
    /// under the stable bridge basename. The executable remains in its signed
    /// bundle (copying it out invalidates its Info.plist-bound signature), while
    /// basename dispatch still enters bridge mode before SwiftUI/AppKit startup.
    ///
    /// The stable link preserves the already-validated bundle signature and
    /// lets app launch repair the command target when the app bundle moves.
    init?(
        settingsURL: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json"),
        sourceExecutable: URL? = Bundle.main.executableURL,
        applicationSupportDirectory: URL? = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
        fileManager: FileManager = .default
    ) {
        guard let sourceExecutable,
              let applicationSupportDirectory,
              fileManager.fileExists(atPath: sourceExecutable.path),
              let bridgeExecutable = try? Self.prepareBridgeLink(
                  sourceExecutable: sourceExecutable,
                  applicationSupportDirectory: applicationSupportDirectory,
                  fileManager: fileManager
              )
        else { return nil }
        self.settingsURL = settingsURL
        self.bridgeExecutable = bridgeExecutable
        self.bridgeCommand = "\(Self.shellQuoted(bridgeExecutable.path)) --quiet"
        self.managedDefaults = .standard
    }

    init(settingsURL: URL, bridgeExecutable: URL) {
        self.settingsURL = settingsURL
        self.bridgeExecutable = bridgeExecutable
        self.bridgeCommand = "\(Self.shellQuoted(bridgeExecutable.path)) --quiet"
        self.managedDefaults = nil
    }

    static func prepareBridgeLink(
        sourceExecutable: URL,
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let parentDirectory = applicationSupportDirectory
            .appendingPathComponent("CodexUsageMonitor", isDirectory: true)
        let destinationDirectory = parentDirectory
            .appendingPathComponent("ClaudeBridge", isDirectory: true)
        let destination = destinationDirectory.appendingPathComponent(bridgeExecutableName)
        let staging = destinationDirectory
            .appendingPathComponent(".claude-usage-bridge-\(UUID().uuidString)")

        try fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: parentDirectory.path
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: destinationDirectory.path
        )
        guard hasValidCodeSignature(sourceExecutable) else {
            throw ClaudeStatusLinePreparationError.invalidCodeSignature
        }
        try fileManager.createSymbolicLink(at: staging, withDestinationURL: sourceExecutable)
        defer { try? fileManager.removeItem(at: staging) }

        // Validate through the link too, proving the exact command target
        // resolves to the signed bundle executable.
        guard hasValidCodeSignature(staging) else {
            throw ClaudeStatusLinePreparationError.invalidCodeSignature
        }

        // POSIX rename atomically replaces the previous file or symlink without
        // following it. This also migrates the released copied helper in place.
        guard rename(staging.path, destination.path) == 0 else {
            throw ClaudeStatusLinePreparationError.renameFailed(errno)
        }
        return destination
    }

    private static func hasValidCodeSignature(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil)
            == errSecSuccess
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
            managedDefaults?.set(true, forKey: Self.managedDefaultsKey)
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
        managedDefaults?.set(true, forKey: Self.managedDefaultsKey)
        return .installed
    }

    /// Removes only the exact statusLine entry installed by this app, then its
    /// copied executable and passive snapshot. A changed or foreign command is
    /// preserved even if an old managed marker remains.
    func uninstallManagedCapture(fileManager: FileManager = .default) {
        guard managedDefaults?.bool(forKey: Self.managedDefaultsKey) == true else { return }
        defer { managedDefaults?.removeObject(forKey: Self.managedDefaultsKey) }
        switch inspect(fileManager: fileManager) {
        case .installed:
            guard let data = try? Data(contentsOf: settingsURL),
                  var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            root.removeValue(forKey: "statusLine")
            guard let updated = try? JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            ), (try? updated.write(to: settingsURL, options: .atomic)) != nil else { return }
        case .notConfigured, .foreign:
            break
        case .repairable, .settingsUnreadable:
            // The command might still reference this path, but is not the
            // exact managed value. Preserve it until the user repairs it.
            return
        }

        try? fileManager.removeItem(at: bridgeExecutable)
        let snapshot = bridgeExecutable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("claude-rate-limits.json")
        try? fileManager.removeItem(at: snapshot)
    }
}

enum ClaudeStatusLinePreparationError: Error {
    case invalidCodeSignature
    case renameFailed(Int32)
}
