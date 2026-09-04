import SwiftUI

@main
struct Season42App: App {
    private let library: Library
    private let settings = AppSettings()

    init() {
        do {
            library = try Library.onDisk()
        } catch {
            // The app is nothing without the user's own data, and the Library is now the
            // whole of it (ADR-0005); there is no useful degraded mode.
            fatalError("Could not open the Library store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(library: library, settings: settings)
        }
    }
}
