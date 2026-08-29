// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexUsageMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexUsageMonitor", targets: ["CodexUsageMonitor"]),
    ],
    targets: [
        // Pure, dependency-free logic shared by the bridge CLI and its tests:
        // decode a Claude Code statusLine payload, extract the rate-limit
        // windows, and atomically write the snapshot the app reads.
        .target(name: "ClaudeUsageBridgeCore"),
        .executableTarget(
            name: "CodexUsageMonitor",
            dependencies: ["ClaudeUsageBridgeCore"]
        ),
        .testTarget(
            name: "CodexUsageMonitorTests",
            dependencies: ["CodexUsageMonitor", "ClaudeUsageBridgeCore"]
        ),
    ]
)
