import SwiftUI

@main
struct Season42App: App {
    private let library: Library
    private let catalog: Catalog
    /// The one Catalog source the running app has: the API, at the address `CatalogApi`
    /// is configured with.
    private let api: any CatalogFetching = CatalogApi()

    init() {
        do {
            library = try Library.onDisk()
        } catch {
            // The app is nothing without the user's own data; there is no useful degraded mode.
            fatalError("Could not open the Library store: \(error)")
        }
        catalog = Self.cachedCatalog()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(library: library, catalog: catalog, api: api)
        }
    }

    /// The Catalog cache, filled from the bundled snapshot on a first launch. Unlike the
    /// Library, a Catalog that won't open or won't load is something the app survives:
    /// everything the user tracks is still theirs, so the Catalog tab says it has nothing
    /// rather than the app refusing to start.
    private static func cachedCatalog() -> Catalog {
        do {
            let catalog = try Catalog.onDisk()
            // A snapshot that won't load leaves the tab saying so; anything cached by an
            // earlier launch is still there, which is the better of the two outcomes.
            try? catalog.fillFromBundledSnapshotIfEmpty()
            return catalog
        } catch {
            do {
                // The cache is disposable — a Catalog is shared data the app can fetch
                // again — so a store that won't open is worth a throwaway one, not a crash.
                return try Catalog.inMemory()
            } catch {
                fatalError("Could not open a Catalog cache: \(error)")
            }
        }
    }
}
