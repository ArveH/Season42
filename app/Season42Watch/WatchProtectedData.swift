import WatchKit

/// Protected data as the Watch App can tell it. watchOS says nothing about protected data
/// itself, so this goes by what the app can see: a watch that is locked never has the app
/// in front of the user, so an app that is not in the background can read its store. One
/// woken in the background — by an iCloud push, say — waits until the user brings it
/// forward, rather than risk reading a locked store as a broken one and keeping it aside
/// (ADR-0023).
struct WatchProtectedData: ProtectedData {
    var isAvailable: Bool { WKApplication.shared().applicationState != .background }

    func waitUntilAvailable() async {
        // Listening before looking, so a move to the foreground between the two isn't missed.
        let becameActive = NotificationCenter.default.notifications(
            named: WKApplication.didBecomeActiveNotification
        )
        guard !isAvailable else { return }
        for await _ in becameActive where isAvailable {
            return
        }
    }
}
