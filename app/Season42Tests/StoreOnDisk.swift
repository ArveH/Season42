import Foundation
@testable import Season42

/// A directory of its own for a store, so a test can see everything left beside it.
func temporaryStoreDirectory(named name: String = UUID().uuidString) throws -> URL {
    let directory = URL.temporaryDirectory.appending(path: name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

extension Library {
    /// The store at `url`, opened the way an everyday launch opens the app's own: protected
    /// data is already there, so the open happens at once.
    static func onDiskOnAnUnlockedDevice(at url: URL) throws -> Library {
        guard let library = try onDiskIfReadable(at: url, protectedData: UnlockedDevice())
        else { throw UnlockedDeviceRefused() }
        return library
    }
}

/// A device unlocked since boot — every device, on every launch but a background one
/// before the first unlock.
@MainActor
struct UnlockedDevice: ProtectedData {
    var isAvailable: Bool { true }
    func waitUntilAvailable() async {}
}

private struct UnlockedDeviceRefused: Error {}
