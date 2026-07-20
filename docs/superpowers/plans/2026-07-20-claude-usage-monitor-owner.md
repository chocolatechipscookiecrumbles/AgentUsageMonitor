# Claude Usage Monitor Owner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the single owner for the Claude rate-limit read cycle (`ClaudeUsageMonitor`, mirroring `CodexConnectionController`'s lifecycle shape) and a tested, non-destructive one-click `statusLine` installer (`ClaudeStatusLineInstaller`) — both isolated and unit-tested, with no wiring into `ClaudeCodePreviewSettingsView` or any visible Settings control yet.

**Architecture:** `ClaudeUsageMonitor` is a `@MainActor` `ObservableObject` that owns polling `ClaudeRateLimitSnapshotReader` (from the [statusLine usage bridge plan](2026-07-20-claude-statusline-usage-bridge.md)) on a timer and publishes a small two-case `ClaudeUsageState`. Because the bridge only ever produces a "last known" snapshot — there is no live request this app can make, unlike Codex's confirmed/cached-last-known-good distinction — the state model is deliberately simpler than `AgentConnectionState`/`ConfirmationState`: either a snapshot is available (display its `capturedAt` as relative time) or it isn't. `ClaudeStatusLineInstaller` is a separate, narrowly-scoped file mutator that merges a `statusLine` entry into `~/.claude/settings.json` without ever overwriting an existing unrelated `statusLine` or malformed file.

**Tech Stack:** Swift 6.2, Foundation, Combine (`ObservableObject`), XCTest — no new dependencies.

## Global Constraints

- Do not reuse `AgentConnectionState`/`ConfirmationState`; those model Codex's authenticated-connection and retry-confirmation machinery, which doesn't apply here (no sign-in, no live request, no retry).
- `ClaudeUsageMonitor` must never make a network request, read credentials, or invoke `claude`/`claude-usage-bridge` itself — it only reads the file `ClaudeRateLimitSnapshotReader` already reads.
- `ClaudeStatusLineInstaller` must never silently overwrite an existing `statusLine` entry that isn't already this app's bridge command, and must never write to `~/.claude/settings.json` if the existing file fails to parse as JSON — both cases return a distinct result and leave the file untouched.
- Do not modify `ClaudeCodePreviewSettingsView.swift`, `AgentSettingsCatalog.swift`, `AgentProvider.swift`, or `SettingsView.swift`, and do not add a Settings button that calls the installer. Per the [capability research gate](2026-07-20-claude-code-capability-research.md#gate-before-implementation), criteria 3 (product-copy accuracy) and 5 (explicit "not available" fallback UI) are UI-layer work reserved for a follow-up plan.
- `ClaudeStatusLineInstaller`'s production `bridgeDirectory` path depends on `ClaudeUsageBridge/` being bundled into the signed `.app` (a `CodexUsageMonitor/Scripts/build-app.sh` change not yet done). This plan does not do that bundling; both initializer parameters are required (no defaults) so no call site can silently point at a wrong path.
- Keep tests narrow and deterministic per `AGENTS.md`.

---

## File Structure

- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageState.swift` — `ClaudeUsageState`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift` — `ClaudeUsageMonitor`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift` — `ClaudeStatusLineInstallResult`, `ClaudeStatusLineInstaller`
- Create: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeStatusLineInstallerTests.swift`
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md` — record this as further gate-criterion-4 evidence
- Modify: `docs/product/planning-board.md` — bookkeeping

---

## Task 1: `ClaudeUsageState` + `ClaudeUsageMonitor`

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageState.swift`
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift`

**Interfaces:**
- Consumes: `ClaudeRateLimitSnapshotReader`/`ClaudeRateLimitSnapshot` from the statusLine bridge plan.
- Produces: `enum ClaudeUsageState: Equatable, Sendable { case notAvailable; case available(ClaudeRateLimitSnapshot) }`; `@MainActor final class ClaudeUsageMonitor: ObservableObject` with `@Published private(set) var state`, `init(reader:pollInterval:)`, `func start()`, `func stop()`, `func refreshNow()`.

- [ ] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeUsageMonitorTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeUsageMonitorTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("claude-rate-limits.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @MainActor
    func testStateIsNotAvailableBeforeAnySnapshotExists() {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))

        monitor.refreshNow()

        XCTAssertEqual(monitor.state, .notAvailable)
    }

    @MainActor
    func testStateBecomesAvailableAfterSnapshotWritten() throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))
        let json = """
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """
        try Data(json.utf8).write(to: fileURL)

        monitor.refreshNow()

        guard case .available(let snapshot) = monitor.state else {
            return XCTFail("Expected .available")
        }
        XCTAssertEqual(snapshot.fiveHour?.usedPercentage, 5.0)
    }

    @MainActor
    func testStateReturnsToNotAvailableIfSnapshotDisappears() throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL))
        try Data("""
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """.utf8).write(to: fileURL)
        monitor.refreshNow()
        XCTAssertNotEqual(monitor.state, .notAvailable)

        try FileManager.default.removeItem(at: fileURL)
        monitor.refreshNow()

        XCTAssertEqual(monitor.state, .notAvailable)
    }

    @MainActor
    func testStartReadsImmediatelyWithoutWaitingForFirstTick() {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL), pollInterval: .seconds(300))

        monitor.start()

        XCTAssertEqual(monitor.state, .notAvailable)
        monitor.stop()
    }

    @MainActor
    func testStopPreventsFurtherPolling() async throws {
        let monitor = ClaudeUsageMonitor(reader: ClaudeRateLimitSnapshotReader(fileURL: fileURL), pollInterval: .milliseconds(20))
        monitor.start()
        monitor.stop()
        try Data("""
        {"schemaVersion": 1, "capturedAt": 1700000000, "fiveHour": {"usedPercentage": 5.0, "resetsAt": 1800000000}}
        """.utf8).write(to: fileURL)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(monitor.state, .notAvailable)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageMonitorTests`
Expected: FAIL to build — `cannot find 'ClaudeUsageMonitor' in scope`

- [ ] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageState.swift`:

```swift
import Foundation

enum ClaudeUsageState: Equatable, Sendable {
    case notAvailable
    case available(ClaudeRateLimitSnapshot)
}
```

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift`:

```swift
import Foundation

@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    @Published private(set) var state: ClaudeUsageState = .notAvailable

    private let reader: ClaudeRateLimitSnapshotReader
    private let pollInterval: Duration
    private var pollTask: Task<Void, Never>?

    init(reader: ClaudeRateLimitSnapshotReader = ClaudeRateLimitSnapshotReader(), pollInterval: Duration = .seconds(30)) {
        self.reader = reader
        self.pollInterval = pollInterval
    }

    deinit {
        pollTask?.cancel()
    }

    /// Starts polling. Reads once immediately so callers see a state without
    /// waiting a full interval, then re-reads on the configured cadence.
    /// Polling only re-reads a small local file — unlike Codex's network
    /// refresh, this carries no cost or rate-limit concern at any interval.
    func start() {
        guard pollTask == nil else { return }
        refreshNow()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { return }
                await self.refreshNow()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshNow() {
        if let snapshot = reader.readSnapshot() {
            state = .available(snapshot)
        } else {
            state = .notAvailable
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeUsageMonitorTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageState.swift \
  CodexUsageMonitor/Sources/CodexUsageMonitor/Quota/ClaudeUsageMonitor.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeUsageMonitorTests.swift
git commit -m "Add ClaudeUsageMonitor as the sole owner of the Claude rate-limit read cycle"
```

---

## Task 2: `ClaudeStatusLineInstaller`

**Files:**
- Create: `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift`
- Test: `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeStatusLineInstallerTests.swift`

**Interfaces:**
- Produces: `enum ClaudeStatusLineInstallResult: Equatable { case installed; case alreadyInstalled; case existingCustomStatusLineFound; case unableToUpdateSettings }`; `struct ClaudeStatusLineInstaller { init(settingsURL: URL, bridgeDirectory: URL); func install() -> ClaudeStatusLineInstallResult }`.

- [ ] **Step 1: Write the failing tests**

Create `CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeStatusLineInstallerTests.swift`:

```swift
import XCTest
@testable import CodexUsageMonitor

final class ClaudeStatusLineInstallerTests: XCTestCase {
    private var tempDirectory: URL!
    private var settingsURL: URL!
    private var bridgeDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeStatusLineInstallerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        settingsURL = tempDirectory.appendingPathComponent("settings.json")
        bridgeDirectory = tempDirectory.appendingPathComponent("ClaudeUsageBridge")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testInstallCreatesSettingsFileWhenMissing() throws {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        let statusLine = try XCTUnwrap(json["statusLine"] as? [String: Any])
        XCTAssertEqual(statusLine["type"] as? String, "command")
        XCTAssertEqual(statusLine["command"] as? String, "cd \(bridgeDirectory.path) && python3 -m claude_usage_bridge --quiet")
    }

    func testInstallPreservesExistingUnrelatedKeys() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["theme": "dark", "hooks": ["SessionStart": []]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)

        let result = installer.install()

        XCTAssertEqual(result, .installed)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: settingsURL)) as? [String: Any])
        XCTAssertEqual(json["theme"] as? String, "dark")
        XCTAssertNotNil(json["hooks"])
        XCTAssertNotNil(json["statusLine"])
    }

    func testInstallIsIdempotentWhenAlreadyInstalled() {
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        XCTAssertEqual(installer.install(), .installed)

        XCTAssertEqual(installer.install(), .alreadyInstalled)
    }

    func testInstallRefusesToReplaceExistingCustomStatusLine() throws {
        let existing = try JSONSerialization.data(withJSONObject: ["statusLine": ["type": "command", "command": "my-custom-script.sh"]])
        try existing.write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .existingCustomStatusLineFound)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }

    func testInstallReturnsUnableToUpdateSettingsForMalformedJSONAndLeavesFileUntouched() throws {
        try Data("not json".utf8).write(to: settingsURL)
        let installer = ClaudeStatusLineInstaller(settingsURL: settingsURL, bridgeDirectory: bridgeDirectory)
        let before = try Data(contentsOf: settingsURL)

        let result = installer.install()

        XCTAssertEqual(result, .unableToUpdateSettings)
        XCTAssertEqual(try Data(contentsOf: settingsURL), before)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeStatusLineInstallerTests`
Expected: FAIL to build — `cannot find 'ClaudeStatusLineInstaller' in scope`

- [ ] **Step 3: Write the implementation**

Create `CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift`:

```swift
import Foundation

enum ClaudeStatusLineInstallResult: Equatable {
    case installed
    case alreadyInstalled
    case existingCustomStatusLineFound
    case unableToUpdateSettings
}

/// Merges a statusLine entry pointing at the Claude usage bridge into
/// ~/.claude/settings.json, without ever touching an unrelated existing
/// statusLine or a file that fails to parse as JSON.
struct ClaudeStatusLineInstaller {
    private let settingsURL: URL
    private let bridgeCommand: String

    init(settingsURL: URL, bridgeDirectory: URL) {
        self.settingsURL = settingsURL
        self.bridgeCommand = "cd \(bridgeDirectory.path) && python3 -m claude_usage_bridge --quiet"
    }

    func install() -> ClaudeStatusLineInstallResult {
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            guard let data = try? Data(contentsOf: settingsURL),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return .unableToUpdateSettings }
            root = parsed
        }

        if let existingStatusLine = root["statusLine"] as? [String: Any] {
            if existingStatusLine["command"] as? String == bridgeCommand {
                return .alreadyInstalled
            }
            return .existingCustomStatusLineFound
        }

        root["statusLine"] = ["type": "command", "command": bridgeCommand]

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return .unableToUpdateSettings
        }
        do {
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            return .unableToUpdateSettings
        }
        return .installed
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd CodexUsageMonitor && swift test --filter ClaudeStatusLineInstallerTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full Swift test suite to confirm no regressions**

Run: `cd CodexUsageMonitor && swift test`
Expected: PASS (all existing tests plus the 10 new ones from Tasks 1–2)

- [ ] **Step 6: Commit**

```bash
git add CodexUsageMonitor/Sources/CodexUsageMonitor/Settings/ClaudeStatusLineInstaller.swift \
  CodexUsageMonitor/Tests/CodexUsageMonitorTests/ClaudeStatusLineInstallerTests.swift
git commit -m "Add non-destructive one-click Claude statusLine installer"
```

---

## Task 3: Record evidence in the capability research gate

**Files:**
- Modify: `docs/superpowers/plans/2026-07-20-claude-code-capability-research.md`
- Modify: `docs/product/planning-board.md`

- [ ] **Step 1: Update the capability research doc**

Under "Gate before implementation," append a dated note under criterion 4 confirming the owner now exists:

```markdown
- **2026-07-20 implementation note:** `ClaudeUsageMonitor` (see [usage monitor owner plan](2026-07-20-claude-usage-monitor-owner.md)) is the single owner of the Claude read cycle, with explicit `start()`/`stop()` teardown. `ClaudeStatusLineInstaller` provides a tested, non-destructive setup path. Criteria 3 and 5 (product-copy accuracy, visible "not available" fallback) remain open — no Settings UI exists yet.
```

- [ ] **Step 2: Update the planning board**

Update the Claude local analytics/provider research row's "Next action" to reference this plan, and add it to the plan coverage index.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-07-20-claude-code-capability-research.md docs/product/planning-board.md
git commit -m "Record usage monitor owner as gate criterion 4 evidence"
```

---

## Known gap this plan does not close

`ClaudeStatusLineInstaller`'s `bridgeDirectory` has no production default because `ClaudeUsageBridge/` is not yet bundled into the signed `.app` — that needs a `CodexUsageMonitor/Scripts/build-app.sh` change to copy the bridge into `Contents/Resources/` and a way to resolve it at runtime (e.g. `Bundle.main.resourceURL`). Until that exists, both `ClaudeUsageMonitor` and `ClaudeStatusLineInstaller` are real, tested, and usable from a debug build or a future call site that hand-supplies paths, but not yet reachable by an end user through the shipped app. Name this explicitly in the eventual Settings UI plan rather than assuming it away.

## Self-Review

**1. Spec coverage:** Owner class (Task 1) mirrors `CodexConnectionController`'s `start()`/`stop()`/`deinit`-cancels-task shape while using a state model honest about the bridge's "last known only" nature, per your scoping answer. Installer (Task 2) satisfies "build it now" while staying non-destructive per the global constraints. Gate bookkeeping is Task 3.

**2. Placeholder scan:** No `TBD`/`TODO`; every step has complete, runnable code; the bundling gap is named explicitly rather than glossed over.

**3. Type consistency:** `ClaudeUsageState.available` carries exactly `ClaudeRateLimitSnapshot` from the prior plan; `ClaudeUsageMonitor`'s `reader` parameter type matches `ClaudeRateLimitSnapshotReader`'s existing `init(fileURL:)`/`init(fileManager:)` signatures with no changes needed to that file.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-claude-usage-monitor-owner.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
