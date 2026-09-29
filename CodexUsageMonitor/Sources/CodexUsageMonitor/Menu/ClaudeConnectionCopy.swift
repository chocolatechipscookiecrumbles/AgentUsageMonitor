enum ClaudeConnectionCopy {
    static let keychainDisclosure =
        "Enables passive usage capture and reads Claude Code’s existing Keychain credential for live fallback. Your custom status line is preserved."

    static let keychainPromptExplanation =
        "Connect or Reconnect may ask for Keychain permission. Choose Always Allow to permit silent reads. Passive monitoring continues if access is unavailable. Agent Monitor never changes or deletes Claude Code’s credential."

    static let connectionDisclosure =
        "\(keychainDisclosure) \(keychainPromptExplanation)"
}
