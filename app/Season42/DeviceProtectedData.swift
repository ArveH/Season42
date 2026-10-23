import UIKit

/// Protected data as the system has it: unavailable from boot until the first unlock.
struct DeviceProtectedData: ProtectedData {
    var isAvailable: Bool { UIApplication.shared.isProtectedDataAvailable }

    func waitUntilAvailable() async {
        // Listening before looking, so an unlock between the two isn't missed.
        let becameAvailable = NotificationCenter.default.notifications(
            named: UIApplication.protectedDataDidBecomeAvailableNotification
        )
        guard !isAvailable else { return }
        for await _ in becameAvailable where isAvailable {
            return
        }
    }
}
