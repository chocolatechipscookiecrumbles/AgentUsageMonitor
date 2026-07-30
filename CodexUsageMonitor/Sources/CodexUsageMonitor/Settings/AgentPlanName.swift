import Foundation

/// Formats the raw plan identifier a provider reports into the name a user
/// would recognize.
///
/// Providers spell these in their own machine style — `pro`, `max_20x`,
/// `chatgpt-plus` — and `.capitalized` alone turns the compound ones into
/// `Max_20x`. Every surface that shows a plan goes through here so the popover
/// header, the Settings pages, and the context rail cannot disagree about how
/// the same account is named.
enum AgentPlanName {
    /// Provider values are external input. Only identifiers observed in the
    /// supported Codex/Claude account contracts are safe to present as plan
    /// names; an unknown value falls back to the provider name at the caller.
    private static let supportedIdentifiers: Set<String> = [
        "free",
        "pro",
        "plus",
        "team",
        "business",
        "enterprise",
        "max",
        "max_5x",
        "max_20x",
        "chatgpt_plus",
        "chatgpt_pro",
        "chatgpt_team",
    ]

    static func display(_ rawPlanType: String?) -> String? {
        guard let rawPlanType else { return nil }
        let words = rawPlanType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " })
        guard !words.isEmpty else { return nil }
        guard supportedIdentifiers.contains(words.joined(separator: "_")) else {
            return nil
        }
        return words.map(capitalize).joined(separator: " ")
    }

    /// A multiplier component keeps its lowercase `x` — `Max 20x`, not
    /// `Max 20X`, which is how Anthropic writes it.
    private static func capitalize(_ word: Substring) -> String {
        if word.first?.isNumber == true { return String(word) }
        return word.prefix(1).uppercased() + word.dropFirst()
    }
}
