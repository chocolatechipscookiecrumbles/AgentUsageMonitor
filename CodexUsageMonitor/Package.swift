// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexUsageMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexUsageMonitor", targets: ["CodexUsageMonitor"]),
        .executable(name: "claude-usage-bridge", targets: ["ClaudeUsageBridge"]),
    ],
    targets: [
        // Pure, dependency-free logic shared by the bridge CLI and its tests:
        // decode a Claude Code statusLine payload, extract the rate-limit
        // windows, and atomically write the snapshot the app reads.
        .target(name: "ClaudeUsageBridgeCore"),
        .executableTarget(name: "CodexUsageMonitor"),
        // The native replacement for the former Python statusLine bridge, so a
        // shipped build no longer depends on the user having python3 installed.
        .executableTarget(
            name: "ClaudeUsageBridge",
            dependencies: ["ClaudeUsageBridgeCore"]
        ),
        .testTarget(
            name: "CodexUsageMonitorTests",
            dependencies: ["CodexUsageMonitor", "ClaudeUsageBridgeCore"]
        ),
    ]
)
