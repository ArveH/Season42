import SwiftUI

@main
struct Season42App: App {
    private let library: Library
    private let settings = AppSettings()
    /// Up when the Library's store couldn't be opened and was kept aside, until the user
    /// has read that it was (ADR-0023) — a Library that comes up empty must say why.
    @State private var tellingOfKeptAsideStore: Bool

    init() {
        do {
            library = try Library.onDisk()
        } catch {
            // Reachable only when the store could be neither kept aside nor replaced by a
            // fresh one; the app is nothing without the user's own data (ADR-0005), and
            // there is no useful degraded mode.
            fatalError("Could not open the Library store: \(error)")
        }
        _tellingOfKeptAsideStore = State(initialValue: library.keptAsideStore != nil)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(library: library, settings: settings)
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
