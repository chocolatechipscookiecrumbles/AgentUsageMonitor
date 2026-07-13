// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexUsageMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexUsageMonitor", targets: ["CodexUsageMonitor"]),
    ],
    targets: [
        .executableTarget(name: "CodexUsageMonitor"),
        .testTarget(
            name: "CodexUsageMonitorTests",
            dependencies: ["CodexUsageMonitor"]
        ),
    ]
)
