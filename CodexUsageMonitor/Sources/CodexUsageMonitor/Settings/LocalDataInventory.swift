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
    ]
}
