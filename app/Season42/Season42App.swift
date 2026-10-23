import SwiftUI

@main
struct Season42App: App {
    /// Open from launch, as it always was, whenever protected data can be read; nil only
    /// when the app is woken before the first unlock since boot, until it can be (ADR-0023).
    @State private var library: Library?
    private let settings = AppSettings()
    /// Up when the Library's store couldn't be opened and was kept aside, until the user
    /// has read that it was (ADR-0023) — a Library that comes up empty must say why.
    @State private var tellingOfKeptAsideStore: Bool

    init() {
        let library: Library?
        do {
            library = try Library.onDiskIfReadable(protectedData: DeviceProtectedData())
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
                    RootTabView(library: library, settings: settings)
                } else {
                    // Only ever up when the app was woken before the first unlock, so no
                    // more than a sign that the Library is on its way.
                    ProgressView()
                }
            }
            .task {
                guard library == nil else { return }
                do {
                    let opened = try await Library.onDisk(protectedData: DeviceProtectedData())
                    library = opened
                    tellingOfKeptAsideStore = opened.keptAsideStore != nil
                } catch {
                    Self.fail(opening: error)
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

    /// Reachable only when the store could be neither kept aside nor replaced by a fresh
    /// one; the app is nothing without the user's own data (ADR-0005), and there is no
    /// useful degraded mode.
    private static func fail(opening error: any Error) -> Never {
        fatalError("Could not open the Library store: \(error)")
    }
}
