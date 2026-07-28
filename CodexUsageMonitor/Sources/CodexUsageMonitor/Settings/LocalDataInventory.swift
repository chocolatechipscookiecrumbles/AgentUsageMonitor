import Foundation

struct LocalDataStoreDescriptor: Identifiable, Sendable {
    let id: String
    let title: String
    let fileName: String
    let retention: String
    let contents: String
}

enum LocalDataInventory {
    static let directory = "~/Library/Application Support/CodexUsageMonitor"

    static let stores = [
        LocalDataStoreDescriptor(
            id: "last-known-good",
            title: "Last confirmed quota",
            fileName: "last-known-good.json",
            retention: "Replaced by the next confirmed result",
            contents: "Hashed account identity and normalized quota fields"
        ),
        LocalDataStoreDescriptor(
            id: "quota-history",
            title: "Quota history",
            fileName: "quota-history.json",
            retention: "90 days, up to 500 observations",
            contents: "Confirmed normalized quota observations"
        ),
        LocalDataStoreDescriptor(
            id: "refresh-diagnostics",
            title: "Refresh diagnostics",
            fileName: "refresh-diagnostics.json",
            retention: "30 days, up to 1,000 outcomes",
            contents: "Timestamps, reasons, classified outcomes, and stable failure kinds"
        ),
        LocalDataStoreDescriptor(
            id: "claude-usage-cache",
            title: "Last confirmed Claude quota",
            fileName: "claude-usage-cache.json",
            retention: "Replaced by the next fresher reading",
            contents: "Normalized Claude quota percentages, reset times, plan type, and any extra-usage amount"
        ),
        LocalDataStoreDescriptor(
            id: "claude-rate-limits",
            title: "Claude statusLine snapshot",
            fileName: "claude-rate-limits.json",
            retention: "Overwritten each time Claude Code renders its status line",
            contents: "Rate-limit percentages and reset times, written by the Claude usage bridge and only read here"
        ),
        // Deliberately has no file name: Token activity is derived in memory
        // while the app runs and is never written anywhere.
        LocalDataStoreDescriptor(
            id: "token-activity",
            title: "Token activity",
            fileName: "None — memory only",
            retention: "Discarded when the app quits and rebuilt after every launch",
            contents: "Timestamps, models, token counts, and opaque identifiers derived from records the agents own; the app writes no activity history of its own"
        ),
    ]
}
