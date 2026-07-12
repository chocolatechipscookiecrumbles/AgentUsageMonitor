import AppKit
import Combine
import Foundation

@MainActor
final class QuotaViewModel: ObservableObject {
    @Published private(set) var presentation = QuotaPresentation.unavailable("Codex quota unavailable. Refresh after signing in to Codex.")
    @Published private(set) var isRefreshing = false
    @Published private(set) var alertsEnabled = UserDefaults.standard.bool(forKey: "alertsEnabled")

    private let quotaRepository = QuotaRepository()
    private lazy var notifier: QuotaNotifier? = {
        Bundle.main.bundleURL.pathExtension == "app" ? QuotaNotifier() : nil
    }()
    private var refreshTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    var menuBarTitle: String {
        guard let remaining = [presentation.fiveHour?.remainingPercent, presentation.weekly?.remainingPercent].compactMap({ $0 }).min() else {
            return "Codex"
        }
        return "Codex \(remaining)%"
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard NSApp.isActive else { return }
                self?.refresh()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { [weak self] in
            guard let self else { return }
            let record = await quotaRepository.refresh()
            let fresh = record.presentation
            presentation = fresh
            isRefreshing = false
            await notifier?.evaluate(fresh)
        }
    }

    func setAlertsEnabled(_ enabled: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard let notifier else {
                alertsEnabled = false
                return
            }
            await notifier.setAlertsEnabled(enabled)
            alertsEnabled = notifier.alertsEnabled
        }
    }
}
