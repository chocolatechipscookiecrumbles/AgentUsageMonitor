import ClaudeUsageBridgeCore
import Foundation

// Native replacement for the former Python statusLine bridge. Claude Code runs
// this on each status-line render, piping its statusLine JSON to stdin. We
// extract only the rate-limit windows, write the local snapshot the app reads,
// and (unless --quiet) print a one-line usage summary.
//
// Usage: claude-usage-bridge [--quiet] [--output <path>]

func run() -> Int32 {
    var quiet = false
    var outputPath = defaultOutputPath()

    var arguments = Array(CommandLine.arguments.dropFirst())
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--quiet":
            quiet = true
        case "--output":
            guard index + 1 < arguments.count else {
                FileHandle.standardError.write(Data("--output requires a path\n".utf8))
                return 2
            }
            outputPath = URL(fileURLWithPath: arguments[index + 1])
            index += 1
        case "-h", "--help":
            print("Usage: claude-usage-bridge [--quiet] [--output <path>]")
            return 0
        default:
            FileHandle.standardError.write(Data("unknown argument: \(arguments[index])\n".utf8))
            return 2
        }
        index += 1
    }

    let input = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let snapshot = extractSnapshot(
        from: decodePayload(input),
        capturedAt: Int(Date().timeIntervalSince1970)
    )

    // A nil snapshot means the payload had no usable rate_limits; leave any
    // previously written snapshot untouched rather than blanking it.
    if let snapshot {
        do {
            try writeSnapshot(snapshot, to: outputPath)
        } catch {
            FileHandle.standardError.write(Data("failed to write snapshot: \(error)\n".utf8))
            // Still print the status line below; a transient write failure
            // should not blank Claude Code's status line.
        }
    }

    if !quiet {
        print(statusLine(for: snapshot))
    }
    return 0
}

exit(run())
