import Darwin
import Foundation

/// Dispatches command-line modes before SwiftUI creates the application.
///
/// The same signed Mach-O is linked from Application Support under the stable
/// `claude-usage-bridge` basename. Claude Code can therefore invoke passive
/// capture without launching AppKit, constructing the menu, or starting any
/// background monitor.
@main
enum AgentUsageMonitorEntryPoint {
    static func main() {
        if ClaudeUsageBridgeCommand.shouldRun(arguments: CommandLine.arguments) {
            exit(ClaudeUsageBridgeCommand.run(arguments: CommandLine.arguments))
        }
        if MenuHost.isInvalidRequest {
            FileHandle.standardError.write(Data((MenuHost.usage + "\n").utf8))
            exit(64)
        }
        CodexUsageMonitorApp.main()
    }
}
