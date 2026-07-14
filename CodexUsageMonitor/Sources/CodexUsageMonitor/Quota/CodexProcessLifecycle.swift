import Darwin
import Foundation

enum CodexProcessLifecycle {
    static func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        while process.isRunning, clock.now < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !process.isRunning
    }

    static func stop(_ process: Process, gracePeriod: TimeInterval = 1) {
        if process.isRunning {
            process.terminate()
        }
        if !waitForExit(process, timeout: gracePeriod) {
            kill(process.processIdentifier, SIGKILL)
            _ = waitForExit(process, timeout: gracePeriod)
        }
        if !process.isRunning {
            process.waitUntilExit()
        }
    }
}
