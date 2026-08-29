import ClaudeUsageBridgeCore
import Foundation

enum ClaudeUsageBridgeCommand {
    static let explicitFlag = "--claude-usage-bridge"
    static let executableName = "claude-usage-bridge"

    static func shouldRun(arguments: [String]) -> Bool {
        guard let executable = arguments.first else { return false }
        return URL(fileURLWithPath: executable).lastPathComponent == executableName
            || arguments.contains(explicitFlag)
    }

    static func run(arguments: [String]) -> Int32 {
        var quiet = false
        var outputPath = defaultOutputPath()
        let arguments = Array(arguments.dropFirst()).filter { $0 != explicitFlag }

        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--quiet":
                quiet = true
            case "--output":
                guard index + 1 < arguments.count else {
                    writeError("--output requires a path\n")
                    return 2
                }
                outputPath = URL(fileURLWithPath: arguments[index + 1])
                index += 1
            case "-h", "--help":
                print("Usage: claude-usage-bridge [--quiet] [--output <path>]")
                return 0
            default:
                writeError("unknown argument: \(arguments[index])\n")
                return 2
            }
            index += 1
        }

        let input = String(
            data: FileHandle.standardInput.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let snapshot = extractSnapshot(
            from: decodePayload(input),
            capturedAt: Int(Date().timeIntervalSince1970)
        )

        if let snapshot {
            do {
                try writeSnapshot(snapshot, to: outputPath)
            } catch {
                writeError("failed to write snapshot: \(error)\n")
            }
        }

        if !quiet {
            print(statusLine(for: snapshot))
        }
        return 0
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
