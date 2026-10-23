import Foundation
import Testing
@testable import Season42

/// The Library store is never opened before the device's first unlock since boot: the store
/// is unreadable then, and an open that failed on it would look like a broken store and be
/// kept aside (ADR-0023). An open waits for protected data instead. The device is a double
/// here, so none of this needs a locked phone.
@MainActor
struct ProtectedDataTests {
    @Test func whileProtectedDataIsUnavailableTheStoreIsNeitherOpenedNorKeptAside() async throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        // A file that won't open as a store: had the open been tried, it would be gone.
        try Data("not a store".utf8).write(to: storeURL)
        let device = LockedDevice()

        let opening = Task { try await Library.onDisk(at: storeURL, protectedData: device) }
        while !device.isBeingWaitedFor { await Task.yield() }

        #expect(try contents(of: directory) == ["default.store"])
        #expect(try Data(contentsOf: storeURL) == Data("not a store".utf8))

        device.unlock()
        let library = try await opening.value

        // Once it can be read, the store is opened as on any launch — and this one, not
        // being a store, is kept aside the way it always would have been.
        #expect(library.keptAsideStore != nil)
    }

    @Test func onceProtectedDataIsAvailableTheStoreOpensAsItWas() async throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Library(container: try Library.container(at: storeURL))
            .addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let device = LockedDevice()

        let opening = Task { try await Library.onDisk(at: storeURL, protectedData: device) }
        while !device.isBeingWaitedFor { await Task.yield() }
        device.unlock()
        let library = try await opening.value

        #expect(library.trackedSeries.map(\.title) == ["Severance"])
        #expect(library.keptAsideStore == nil)
    }

    /// The everyday launch: protected data is already there, and the store opens there and
    /// then — before the first frame, as it always did — without waiting on anything.
    @Test func anUnlockedDeviceOpensTheStoreAtOnce() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Library(container: try Library.container(at: storeURL))
            .addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let device = LockedDevice()
        device.unlock()

        let library = try #require(try Library.onDiskIfReadable(at: storeURL, protectedData: device))

        #expect(library.trackedSeries.map(\.title) == ["Severance"])
        #expect(!device.wasEverWaitedFor)
    }

    /// A launch before the first unlock can't open the store there and then, and doesn't
    /// try: it leaves the store as it is, for an open that waits, rather than waiting itself.
    @Test func aLockedDeviceLeavesTheStoreUnopenedWithoutWaiting() throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Data("not a store".utf8).write(to: storeURL)
        let device = LockedDevice()

        let library = try Library.onDiskIfReadable(at: storeURL, protectedData: device)

        #expect(library == nil)
        #expect(!device.wasEverWaitedFor)
        #expect(try contents(of: directory) == ["default.store"])
        #expect(try Data(contentsOf: storeURL) == Data("not a store".utf8))
    }

    private func contents(of directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
            .sorted()
    }
}

/// A device that has not been unlocked since boot until the test unlocks it.
@MainActor
private final class LockedDevice: ProtectedData {
    private var isUnlocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var wasEverWaitedFor = false

    var isBeingWaitedFor: Bool { !waiters.isEmpty }
    var isAvailable: Bool { isUnlocked }

    func unlock() {
        isUnlocked = true
        let waiting = waiters
        waiters = []
        for waiter in waiting { waiter.resume() }
    }

    func waitUntilAvailable() async {
        guard !isUnlocked else { return }
        wasEverWaitedFor = true
        await withCheckedContinuation { waiters.append($0) }
    }
}
