import CloudKit

/// Whether the Watch App can reach the user's iCloud. Unlike the iPhone, it has no Library
/// of its own to fall back on: everything it lists came through iCloud (ADR-0022), so
/// without an account it says so rather than looking empty.
@MainActor
@Observable
final class ICloudAccount {
    /// True once iCloud has said there is no account the app can use. False until it has
    /// answered, so the listing is drawn while the answer is on its way.
    private(set) var isUnavailable = false

    /// Asks iCloud again. An answer that can't be had leaves the last one standing.
    func check() async {
        guard let status = try? await CKContainer(identifier: Library.iCloudContainer)
            .accountStatus()
        else { return }
        switch status {
        case .available:
            isUnavailable = false
        case .noAccount, .restricted, .temporarilyUnavailable:
            isUnavailable = true
        case .couldNotDetermine:
            break
        @unknown default:
            break
        }
    }
}
