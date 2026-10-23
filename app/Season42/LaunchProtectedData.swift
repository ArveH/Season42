import Foundation

/// The protected data the app opens its Library against: the device's own, or — in a debug
/// build launched with `-simulateLockedLaunch [seconds]` — a launch before the first unlock
/// that unlocks after that many seconds, three if none are given. The simulator never locks
/// protected data, so this is the only way to see the app wait for it there (ADR-0023). The
/// scheme carries the argument, switched off.
@MainActor
enum LaunchProtectedData {
    static let argument = "-simulateLockedLaunch"

    static func from(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: @escaping @MainActor () -> Date = Date.init
    ) -> any ProtectedData {
        #if DEBUG
        if let index = arguments.firstIndex(of: argument) {
            let next = arguments.index(after: index)
            let seconds = next < arguments.endIndex ? TimeInterval(arguments[next]) : nil
            return SimulatedLockedLaunch(
                unlocksAt: now().addingTimeInterval(seconds ?? 3),
                now: now
            )
        }
        #endif
        return DeviceProtectedData()
    }
}

#if DEBUG
/// A device that was launched before its first unlock and is unlocked at `unlocksAt`.
private struct SimulatedLockedLaunch: ProtectedData {
    let unlocksAt: Date
    let now: @MainActor () -> Date

    var isAvailable: Bool { now() >= unlocksAt }

    func waitUntilAvailable() async {
        while !isAvailable {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
#endif
