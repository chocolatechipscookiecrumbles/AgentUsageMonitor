enum MenuPopoverStatus: Equatable, Sendable {
    case confirmed
    case cached
    case refreshing
    case unavailable

    var title: String {
        switch self {
        case .confirmed: "Confirmed"
        case .cached: "Cached"
        case .refreshing: "Refreshing"
        case .unavailable: "Unavailable"
        }
    }
}
