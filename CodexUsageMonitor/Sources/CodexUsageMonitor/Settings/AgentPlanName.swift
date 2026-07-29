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
    static func display(_ rawPlanType: String?) -> String? {
        guard let rawPlanType else { return nil }
        let words = rawPlanType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " })
            .map(capitalize)
        guard !words.isEmpty else { return nil }
        return words.joined(separator: " ")
    }

    /// A multiplier component keeps its lowercase `x` — `Max 20x`, not
    /// `Max 20X`, which is how Anthropic writes it.
    private static func capitalize(_ word: Substring) -> String {
        if word.first?.isNumber == true { return String(word) }
        return word.prefix(1).uppercased() + word.dropFirst()
    }
}
