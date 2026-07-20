import Foundation

enum ClaudeStatusLineInstallResult: Equatable {
    case installed
    case alreadyInstalled
    case existingCustomStatusLineFound
    case unableToUpdateSettings
}

/// Merges a statusLine entry pointing at the Claude usage bridge into
/// ~/.claude/settings.json, without ever touching an unrelated existing
/// statusLine or a file that fails to parse as JSON.
struct ClaudeStatusLineInstaller {
    private let settingsURL: URL
    private let bridgeCommand: String

    init(settingsURL: URL, bridgeDirectory: URL) {
        self.settingsURL = settingsURL
        self.bridgeCommand = "cd \(bridgeDirectory.path) && python3 -m claude_usage_bridge --quiet"
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
