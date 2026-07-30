import CoreServices
import Foundation

/// One recursive, debounced file-system stream for a provider's records roots.
///
/// Only a semantic "writes under these roots have settled" signal leaves this
/// type. The changed paths FSEvents reports are deliberately dropped rather
/// than coalesced and published, because a path is a project name.
///
/// The stream holds an unretained reference to its observer, so `stop()` must
/// run before the observer is released. The monitor owns observers for the
/// lifetime of the application, which is the only case that occurs in the app.
@MainActor
final class LocalActivityFileObserver {
    private let roots: [URL]
    private let debounce: Duration
    private let onSettled: () -> Void
    private var stream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?

    init(roots: [URL], debounce: Duration = .seconds(1), onSettled: @escaping () -> Void) {
        self.roots = roots
        self.debounce = debounce
        self.onSettled = onSettled
    }

    func start() {
        guard stream == nil, !roots.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let observer = Unmanaged<LocalActivityFileObserver>.fromOpaque(info).takeUnretainedValue()
            // The stream is scheduled on the main queue, so this callback is
            // already running with main-actor isolation.
            MainActor.assumeIsolated { observer.scheduleSettled() }
        }

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            roots.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            // Directory-level events are enough: the monitor rescans the
            // provider rather than acting on any individual path.
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot)
        ) else { return }

        FSEventStreamSetDispatchQueue(created, DispatchQueue.main)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return
        }
        stream = created
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Collapses a burst of writes into one signal once they stop arriving, so
    /// an active agent session does not schedule a scan per written record.
    private func scheduleSettled() {
        debounceTask?.cancel()
        let debounce = debounce
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled, let self else { return }
            self.debounceTask = nil
            self.onSettled()
        }
    }
}
