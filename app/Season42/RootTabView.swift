import SwiftUI

struct RootTabView: View {
    let library: Library
    let catalog: Catalog

    var body: some View {
        TabView {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    switch tab {
                    case .watching: WatchingView(library: library)
                    case .library: LibraryView(library: library)
                    case .catalog: CatalogView(catalog: catalog, library: library)
                    }
                }
            }
        }
    }
}

#Preview {
    RootTabView(library: try! Library.inMemory(), catalog: try! Catalog.inMemory())
}
