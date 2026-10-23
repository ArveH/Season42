import Foundation

/// Whether the device's protected data can be read — which it can't before the first unlock
/// since boot, when iCloud may still wake the app in the background (ADR-0022). The Library
/// store is protected data, and an open tried on it then would fail as if the store were
/// broken and keep it aside (ADR-0023), so the Library waits on this before opening it.
///
/// The app answers from the system; tests hand in a device they unlock themselves.
@MainActor
protocol ProtectedData {
    /// Returns once protected data can be read — at once, when it already can.
    func waitUntilAvailable() async
}
