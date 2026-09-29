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
        case .repairable: return "Repair Passive Capture"
        case .notConfigured: return "Set Up Passive Capture"
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
    private let sourceExecutable: URL?
    private let applicationSupportDirectory: URL?
    private let bridgeExecutable: URL
    private let bridgeCommand: String
    private let managedDefaults: UserDefaults?
    private let needsBridgeLinkPreparation: Bool

    /// Production path: create an app-owned symlink to this app's signed Mach-O
    /// under the stable bridge basename. The executable remains in its signed
    /// bundle (copying it out invalidates its Info.plist-bound signature), while
    /// basename dispatch still enters bridge mode before SwiftUI/AppKit startup.
    ///
    /// The stable link preserves the already-validated bundle signature and
    /// lets app launch repair the command target when the app bundle moves.
    init(
        settingsURL: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json"),
        sourceExecutable: URL? = Bundle.main.executableURL,
        applicationSupportDirectory: URL? = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
    ) {
        let applicationSupportDirectory = applicationSupportDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        self.settingsURL = settingsURL
        self.sourceExecutable = sourceExecutable
        self.applicationSupportDirectory = applicationSupportDirectory
        self.bridgeExecutable = Self.bridgeExecutable(in: applicationSupportDirectory)
        self.bridgeCommand = "\(Self.shellQuoted(self.bridgeExecutable.path)) --quiet"
        self.managedDefaults = .standard
        self.needsBridgeLinkPreparation = true
    }

    init(settingsURL: URL, bridgeExecutable: URL) {
        self.settingsURL = settingsURL
        self.sourceExecutable = nil
        self.applicationSupportDirectory = nil
        self.bridgeExecutable = bridgeExecutable
        self.bridgeCommand = "\(Self.shellQuoted(bridgeExecutable.path)) --quiet"
        self.managedDefaults = nil
        self.needsBridgeLinkPreparation = false
    }

    private static func bridgeExecutable(in applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("CodexUsageMonitor", isDirectory: true)
            .appendingPathComponent("ClaudeBridge", isDirectory: true)
            .appendingPathComponent(bridgeExecutableName)
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

    private func prepareBridgeLinkIfNeeded(fileManager: FileManager = .default) -> Bool {
        guard needsBridgeLinkPreparation else { return true }
        guard let sourceExecutable, let applicationSupportDirectory else { return false }
        do {
            _ = try Self.prepareBridgeLink(
                sourceExecutable: sourceExecutable,
                applicationSupportDirectory: applicationSupportDirectory,
                fileManager: fileManager
            )
            return true
        } catch {
            return false
        }
    }

    /// Repairs the stable link after an app move or update, but only when a
    /// prior explicit installation recorded durable management consent.
    func repairManagedLinkIfNeeded(fileManager: FileManager = .default) {
        guard managedDefaults?.bool(forKey: Self.managedDefaultsKey) == true else { return }
        _ = prepareBridgeLinkIfNeeded(fileManager: fileManager)
    }

    /// The released Python bridge command this project previously installed.
    /// Only this exact form is project-owned; a working command that merely
    /// mentions its module or basename remains the user's status line.
    private static func isSupersededProjectBridge(_ command: String) -> Bool {
        guard let path = firstReferencedPath(in: command),
              URL(fileURLWithPath: path).lastPathComponent == "ClaudeUsageBridge"
        else { return false }
        return command == "cd '\(path)' && python3 -m claude_usage_bridge --quiet"
    }

    private enum LoadedSettings {
        case missing
        case unreadable
        case loaded(root: [String: Any], statusLineCommand: String?)
    }

    private func loadSettings(fileManager: FileManager) -> LoadedSettings {
        guard fileManager.fileExists(atPath: settingsURL.path) else { return .missing }
        guard let data = try? Data(contentsOf: settingsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .unreadable }

        let command = (root["statusLine"] as? [String: Any])?["command"] as? String
        return .loaded(root: root, statusLineCommand: command)
    }

    private func classify(
        _ loadedSettings: LoadedSettings,
        fileManager: FileManager
    ) -> ClaudeStatusLineState {
        let command: String
        switch loadedSettings {
        case .missing:
            return .notConfigured
        case .unreadable:
            return .settingsUnreadable
        case .loaded(_, let statusLineCommand):
            guard let statusLineCommand else { return .notConfigured }
            command = statusLineCommand
        }

        if command == bridgeCommand { return .installed }

        if Self.isSupersededProjectBridge(command) {
            return .repairable(existing: command, reason: .supersededProjectBridge)
        }
        if let path = Self.firstReferencedPath(in: command),
           !fileManager.fileExists(atPath: path) {
            return .repairable(existing: command, reason: .brokenPath)
        }
        return .foreign(existing: command)
    }

    /// Classifies the existing status line without changing anything.
    func inspect(fileManager: FileManager = .default) -> ClaudeStatusLineState {
        classify(loadSettings(fileManager: fileManager), fileManager: fileManager)
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
        let fileManager = FileManager.default
        let loadedSettings = loadSettings(fileManager: fileManager)
        let state = classify(loadedSettings, fileManager: fileManager)
        var root: [String: Any]
        switch loadedSettings {
        case .missing:
            root = [:]
        case .unreadable:
            return .unableToUpdateSettings
        case .loaded(let loadedRoot, _):
            root = loadedRoot
        }

        switch state {
        case .installed:
            guard prepareBridgeLinkIfNeeded(fileManager: fileManager) else {
                return .unableToUpdateSettings
            }
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

        guard prepareBridgeLinkIfNeeded(fileManager: fileManager) else {
            return .unableToUpdateSettings
        }

        root["statusLine"] = ["type": "command", "command": bridgeCommand]

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return .unableToUpdateSettings
        }
        do {
            try fileManager.createDirectory(
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
    /// stable symlink and passive snapshot. A changed, unreadable, or foreign
    /// settings file is preserved, but never prevents removal of app-owned files.
    func uninstallManagedCapture(fileManager: FileManager = .default) {
        defer { managedDefaults?.removeObject(forKey: Self.managedDefaultsKey) }

        let loadedSettings = loadSettings(fileManager: fileManager)
        switch loadedSettings {
        case .loaded(var root, _) where classify(loadedSettings, fileManager: fileManager) == .installed:
            root.removeValue(forKey: "statusLine")
            if let updated = try? JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            ) {
                try? updated.write(to: settingsURL, options: .atomic)
            }
        case .missing, .unreadable, .loaded:
            // The command might still reference this path, but is not the
            // exact managed value. Preserve it until the user repairs it.
            break
        }

        try? fileManager.removeItem(at: bridgeExecutable)
        try? fileManager.removeItem(at: snapshotURL)
    }

    private var snapshotURL: URL {
        bridgeExecutable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("claude-rate-limits.json")
    }
}

enum ClaudeStatusLinePreparationError: Error {
    case invalidCodeSignature
    case renameFailed(Int32)
}
