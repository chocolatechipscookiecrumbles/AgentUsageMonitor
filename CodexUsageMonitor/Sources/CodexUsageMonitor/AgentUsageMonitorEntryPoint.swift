import Darwin
import Foundation

/// Dispatches command-line modes before SwiftUI creates the application.
///
/// The same signed Mach-O is copied to Application Support under the stable
/// `claude-usage-bridge` basename. Claude Code can therefore invoke passive
/// capture without launching AppKit, constructing the menu, or starting any
/// background monitor.
@main
enum AgentUsageMonitorEntryPoint {
    static func main() {
        if ClaudeUsageBridgeCommand.shouldRun(arguments: CommandLine.arguments) {
            exit(ClaudeUsageBridgeCommand.run(arguments: CommandLine.arguments))
        }
        CodexUsageMonitorApp.main()
    }
}
