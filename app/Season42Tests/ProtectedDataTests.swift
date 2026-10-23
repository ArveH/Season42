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

    /// The everyday launch: protected data is already there, and the store opens without
    /// waiting on anything.
    @Test func anUnlockedDeviceOpensTheStoreAtOnce() async throws {
        let directory = try temporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        try Library(container: try Library.container(at: storeURL))
            .addTrackedSeries(title: "Severance", seasons: [9], status: .watching)
        let device = LockedDevice()
        device.unlock()

        let library = try await Library.onDisk(at: storeURL, protectedData: device)

        #expect(library.trackedSeries.map(\.title) == ["Severance"])
        #expect(!device.wasEverWaitedFor)
    }

    private func contents(of directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
            .sorted()
    }

    private func temporaryStoreDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// A device that has not been unlocked since boot until the test unlocks it.
@MainActor
private final class LockedDevice: ProtectedData {
    private var isUnlocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var wasEverWaitedFor = false

    var isBeingWaitedFor: Bool { !waiters.isEmpty }

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
