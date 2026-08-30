enum ClaudeConnectionCopy {
    static let keychainDisclosure =
        "Reads Claude Code’s existing OAuth credential from Keychain and enables passive usage capture without replacing your custom status line."

    static let keychainPromptExplanation =
        "macOS prompts because Agent Monitor and Claude Code are different apps. Choose Always Allow to enable background updates. Agent Monitor never changes or deletes Claude Code’s credential."

    static let connectionDisclosure =
        "\(keychainDisclosure) \(keychainPromptExplanation)"
}
