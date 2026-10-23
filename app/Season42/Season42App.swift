import SwiftUI

@main
struct Season42App: App {
    /// Nil until the store is open — which waits for the first unlock since boot, should
    /// the app be woken before it (ADR-0023).
    @State private var library: Library?
    private let settings = AppSettings()
    /// Up when the Library's store couldn't be opened and was kept aside, until the user
    /// has read that it was (ADR-0023) — a Library that comes up empty must say why.
    @State private var tellingOfKeptAsideStore = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let library {
                    RootTabView(library: library, settings: settings)
                }
            }
            .task {
                guard library == nil else { return }
                do {
                    let opened = try await Library.onDisk(protectedData: DeviceProtectedData())
                    library = opened
                    tellingOfKeptAsideStore = opened.keptAsideStore != nil
                } catch {
                    // Reachable only when the store could be neither kept aside nor
                    // replaced by a fresh one; the app is nothing without the user's own
                    // data (ADR-0005), and there is no useful degraded mode.
                    fatalError("Could not open the Library store: \(error)")
                }
            }
            .alert("Your Library couldn't be opened", isPresented: $tellingOfKeptAsideStore) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Season42 kept it aside, untouched, and started a fresh Library. "
                        + "Nothing was deleted."
                )
            }
        }
    }
}
