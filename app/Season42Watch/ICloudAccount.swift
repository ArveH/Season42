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

    @ObservationIgnored
    nonisolated(unsafe) private var accountChanges: (any NSObjectProtocol)?

    /// Asks again whenever the account on the watch changes — signed in, out, or switched —
    /// rather than waiting for the app to next come to the front.
    init() {
        accountChanges = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    deinit {
        if let accountChanges {
            NotificationCenter.default.removeObserver(accountChanges)
        }
    }

    /// Asks iCloud again. An answer that can't be had leaves the last one standing.
    func check() async {
        guard let status = try? await CKContainer(identifier: Library.iCloudContainer)
            .accountStatus()
        else { return }
        switch status {
        case .available:
            isUnavailable = false
        case .noAccount, .restricted:
            isUnavailable = true
        // There is an account; it is only asking to be signed in again, often for a moment
        // after the watch starts. Blanking the listing over that would hide a Library that
        // is still there.
        case .temporarilyUnavailable, .couldNotDetermine:
            break
        @unknown default:
            break
        }
    }
}
