import SwiftUI

struct RootTabView: View {
    let library: Library
    let catalog: Catalog
    /// Where the Catalog is fetched from, both by the launch's silent Sync and by the
    /// Catalog tab's button.
    let api: any CatalogFetching

    var body: some View {
        TabView {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    switch tab {
                    case .watching: WatchingView(library: library)
                    case .library: LibraryView(library: library)
                    case .catalog: CatalogView(catalog: catalog, library: library, api: api)
                    }
                }
            }
        }
        // Every launch starts a Sync the user didn't ask for, so the Catalog is current
        // without anyone doing anything. An API that isn't there is the ordinary case,
        // not an error: the cache — the bundled snapshot on a first launch — stays put
        // and nothing is said about it.
        .task { await catalog.syncQuietly(using: api) }
    }
}

#Preview {
    RootTabView(
        library: try! Library.inMemory(),
        catalog: try! Catalog.inMemory(),
        api: CatalogApi()
    )
}
