#if DEBUG
import Foundation
import Testing
@testable import Season42

/// `-simulateLockedLaunch [seconds]` makes a debug build launch as if before the device's
/// first unlock, which the simulator never is, so the wait for protected data can be seen
/// there (ADR-0023). Without the argument, the app opens against the device as ever.
@MainActor
struct SimulatedLockedLaunchTests {
    @Test func withoutTheArgumentTheLaunchUsesTheDevice() {
        let protectedData = LaunchProtectedData.from(arguments: ["Season42"])

        #expect(protectedData is DeviceProtectedData)
    }

    @Test func theArgumentLocksTheLaunchForTheSecondsItGives() {
        let clock = TestLaunchClock()

        let protectedData = LaunchProtectedData.from(
            arguments: ["Season42", "-simulateLockedLaunch", "5"],
            now: { clock.now }
        )

        #expect(!protectedData.isAvailable)
        clock.advance(by: 4.9)
        #expect(!protectedData.isAvailable)
        clock.advance(by: 0.1)
        #expect(protectedData.isAvailable)
    }

    @Test func theArgumentAloneLocksTheLaunchForThreeSeconds() {
        let clock = TestLaunchClock()

        // What follows the argument isn't a number of seconds, so the default holds.
        let protectedData = LaunchProtectedData.from(
            arguments: ["Season42", "-simulateLockedLaunch", "-AppleLanguages"],
            now: { clock.now }
        )

        clock.advance(by: 2.9)
        #expect(!protectedData.isAvailable)
        clock.advance(by: 0.1)
        #expect(protectedData.isAvailable)
    }

    @Test func aSimulatedLockedLaunchStopsWaitingOnceItUnlocks() async {
        let clock = TestLaunchClock()
        let protectedData = LaunchProtectedData.from(
            arguments: ["Season42", "-simulateLockedLaunch", "1"],
            now: { clock.now }
        )

        let waiting = Task { await protectedData.waitUntilAvailable() }
        clock.advance(by: 1)
        await waiting.value

        #expect(protectedData.isAvailable)
    }
}

@MainActor
private final class TestLaunchClock {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
#endif
