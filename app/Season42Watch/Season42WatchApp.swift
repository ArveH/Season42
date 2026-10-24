import SwiftUI

/// The Watch App: the Watching tab on the user's Apple Watch, and nothing else. It opens the
/// same Library as the iPhone, synced through the same iCloud container (ADR-0022), and
/// stands on its own — nothing here talks to the phone.
@main
struct Season42WatchApp: App {
    /// Open from launch whenever the app is launched into the foreground; nil while it is
    /// woken in the background, until the user brings it forward (`WatchProtectedData`).
    @State private var library: Library?
    /// Up when the Library's store couldn't be opened and was kept aside, until the user
    /// has read that it was (ADR-0023) — a Library that comes up empty must say why.
    @State private var tellingOfKeptAsideStore: Bool
    private let protectedData = WatchProtectedData()

    init() {
        // Asks iCloud for the Watching Order last picked on the phone, rather than waiting
        // for the system to get round to it.
        NSUbiquitousKeyValueStore.default.synchronize()
        let library: Library?
        do {
            library = try Library.onDiskIfReadable(protectedData: protectedData)
        } catch {
            Self.fail(opening: error)
        }
        _library = State(initialValue: library)
        _tellingOfKeptAsideStore = State(initialValue: library?.keptAsideStore != nil)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let library {
                    WatchingListView(library: library)
                } else {
                    ProgressView()
                }
            }
            .task {
                guard library == nil else { return }
                do {
                    let opened = try await Library.onDisk(protectedData: protectedData)
                    library = opened
                    tellingOfKeptAsideStore = opened.keptAsideStore != nil
                } catch {
                    Self.fail(opening: error)
                }
            }
            .alert("Your Library couldn't be opened", isPresented: $tellingOfKeptAsideStore) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Season42 kept it aside, untouched, and started a fresh Library.")
            }
        }
    }

    /// Reachable only when the store could be neither kept aside nor replaced by a fresh
    /// one, as on the iPhone: there is no useful degraded mode.
    private static func fail(opening error: any Error) -> Never {
        fatalError("Could not open the Library store: \(error)")
    }
}
