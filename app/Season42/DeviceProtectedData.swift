import UIKit

/// Protected data as the system has it: unavailable from boot until the first unlock.
struct DeviceProtectedData: ProtectedData {
    func waitUntilAvailable() async {
        // Listening before looking, so an unlock between the two isn't missed.
        let becameAvailable = NotificationCenter.default.notifications(
            named: UIApplication.protectedDataDidBecomeAvailableNotification
        )
        guard !UIApplication.shared.isProtectedDataAvailable else { return }
        for await _ in becameAvailable where UIApplication.shared.isProtectedDataAvailable {
            return
        }
    }
}
