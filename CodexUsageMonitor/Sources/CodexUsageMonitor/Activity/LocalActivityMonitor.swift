import AppKit
import Foundation

/// The one owner of local Token Activity: which sources exist, when they scan,
/// which file events matter, and what each provider currently shows.
///
/// Scanning starts with application monitoring rather than with quota
/// availability or with the popover opening, so activity stays useful while a
/// provider is disconnected. Everything it derives lives in memory and is
/// rebuilt asynchronously after every launch; no activity history is written.
@MainActor
final class LocalActivityMonitor: ObservableObject {
    @Published private(set) var states: [AgentProvider: ProviderLocalActivityState] = [:]

    private let sources: [AgentProvider: any LocalActivitySource]
    private let rootsByProvider: [AgentProvider: [URL]]
    private let calendar: () -> Calendar
    private var observers: [AgentProvider: LocalActivityFileObserver] = [:]
    private var scanTasks: [AgentProvider: Task<Void, Never>] = [:]
    /// Providers whose records changed while their scan was already running.
    private var rescanRequested: Set<AgentProvider> = []
    /// The reconciled request set behind each published snapshot, kept so a
    /// calendar or time-zone change can rebuild buckets without rereading files.
    private var reconciledRequests: [AgentProvider: [LocalActivityRequest]] = [:]
    private var notificationObservers: [NSObjectProtocol] = []
    private var isRunning = false

    init(
        sources: [AgentProvider: any LocalActivitySource],
        rootsByProvider: [AgentProvider: [URL]],
        calendar: @escaping () -> Calendar = { .autoupdatingCurrent }
    ) {
        self.sources = sources
        self.rootsByProvider = rootsByProvider
        self.calendar = calendar
    }

    convenience init() {
        let claudeRoots = ClaudeLocalActivitySource.defaultProjectRoots(
            environment: ProcessInfo.processInfo.environment
        )
        let codexRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        self.init(
            sources: [
                .codex: CodexLocalActivitySource(sessionsRoot: codexRoot),
                .claudeCode: ClaudeLocalActivitySource(projectRoots: claudeRoots),
            ],
            rootsByProvider: [.codex: [codexRoot], .claudeCode: claudeRoots]
        )
    }

    func state(for provider: AgentProvider) -> ProviderLocalActivityState {
        states[provider] ?? .loading
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        for provider in sources.keys {
            states[provider] = .loading
            startObserver(for: provider)
            scheduleScan(for: provider)
        }
        observeSystemChanges()
    }

    func stop() {
        isRunning = false
        for task in scanTasks.values { task.cancel() }
        scanTasks.removeAll()
        rescanRequested.removeAll()
        for observer in observers.values { observer.stop() }
        observers.removeAll()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    private func startObserver(for provider: AgentProvider) {
        // Watching a root that does not exist would watch its future parents,
        // so absent roots are retried on activation instead.
        let existingRoots = (rootsByProvider[provider] ?? []).filter {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue
        }
        guard !existingRoots.isEmpty else { return }

        let observer = LocalActivityFileObserver(roots: existingRoots) { [weak self] in
            self?.scheduleScan(for: provider)
        }
        observer.start()
        observers[provider] = observer
    }

    private func scheduleScan(for provider: AgentProvider) {
        guard isRunning, let source = sources[provider] else { return }
        guard scanTasks[provider] == nil else {
            // One follow-up scan covers every event that arrived during this
            // one, so repeated file events cannot queue repeated work.
            rescanRequested.insert(provider)
            return
        }

        scanTasks[provider] = Task { [weak self] in
            // The source is an actor, so the read and reconciliation run off
            // the main actor while the menu stays responsive.
            let result = await source.scan(bounds: LocalActivityScanBounds())
            guard !Task.isCancelled else { return }
            self?.apply(result, for: provider)
        }
    }

    private func apply(_ result: LocalActivityScanResult, for provider: AgentProvider) {
        scanTasks[provider] = nil

        switch result.status {
        case .readable:
            // Replacing the whole reconciled set is what keeps repeated file
            // events from double counting a request.
            reconciledRequests[provider] = result.requests
            publish(provider)
        case .localRecordsMissing:
            reconciledRequests[provider] = nil
            states[provider] = .unavailable(.localRecordsMissing)
        case .unsafeToRead:
            reconciledRequests[provider] = nil
            states[provider] = .unavailable(.unsafeToRead)
        }

        if rescanRequested.remove(provider) != nil {
            scheduleScan(for: provider)
        }
    }

    private func publish(_ provider: AgentProvider) {
        guard let requests = reconciledRequests[provider] else { return }
        guard let state = LocalActivityAggregation.state(
            provider: provider,
            requests: requests,
            calendar: calendar()
        ) else {
            // Aggregation only fails when the reconciled set cannot be trusted,
            // which is unavailable rather than a fabricated zero.
            states[provider] = .unavailable(.unsafeToRead)
            return
        }
        states[provider] = state
    }

    /// Day rollover, clock changes, and time-zone changes all move the local
    /// day boundary. They change how existing requests bucket, not what was
    /// observed, so they rebuild from cached requests without touching a file.
    private func observeSystemChanges() {
        let center = NotificationCenter.default
        for name in [
            NSNotification.Name.NSCalendarDayChanged,
            NSNotification.Name.NSSystemClockDidChange,
            NSNotification.Name.NSSystemTimeZoneDidChange,
        ] {
            notificationObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.rebuildBuckets() }
                }
            )
        }
        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.retryAbsentRoots() }
            }
        )
    }

    private func rebuildBuckets() {
        for provider in reconciledRequests.keys { publish(provider) }
    }

    /// A provider the user installed after launch has no watched root yet, so
    /// activation is the moment to look again. Providers already producing
    /// activity are left alone; the popover never triggers a scan.
    private func retryAbsentRoots() {
        for provider in sources.keys where states[provider] == .unavailable(.localRecordsMissing) {
            if observers[provider] == nil { startObserver(for: provider) }
            scheduleScan(for: provider)
        }
    }
}
