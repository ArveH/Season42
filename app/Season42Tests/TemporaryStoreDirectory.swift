import Foundation

/// A directory of its own for a store, so a test can see everything left beside it.
func temporaryStoreDirectory(named name: String = UUID().uuidString) throws -> URL {
    let directory = URL.temporaryDirectory.appending(path: name)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
