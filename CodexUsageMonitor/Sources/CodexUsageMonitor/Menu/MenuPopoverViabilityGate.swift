enum MenuPopoverViabilityGate {
    static let launchArgument = "--window-popover-gate"

    static var isEnabled: Bool {
        CommandLine.arguments.contains(launchArgument)
    }
}
