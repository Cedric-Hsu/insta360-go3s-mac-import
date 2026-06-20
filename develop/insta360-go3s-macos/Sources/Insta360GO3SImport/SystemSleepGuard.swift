import Foundation

/// Prevents system idle sleep during import. Display may dim or turn off.
@MainActor
final class SystemSleepGuard {
    private var activity: NSObjectProtocol?

    func begin(reason: String = "GO 3S WiFi import") {
        end()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: reason
        )
    }

    func end() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
