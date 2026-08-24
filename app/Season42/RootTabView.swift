import SwiftUI

struct RootTabView: View {
    let library: Library

    var body: some View {
        TabView {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    switch tab {
                    case .library: LibraryView(library: library)
                    case .watching, .catalog: PlaceholderView(tab: tab)
                    }
                }
            }
        }
    }
}

/// Empty placeholder shown until each tab's real screen exists.
private struct PlaceholderView: View {
    let tab: AppTab

    var body: some View {
        NavigationStack {
            Text(tab.title)
                .foregroundStyle(.secondary)
                .navigationTitle(tab.title)
        }
    }
}

#Preview {
    RootTabView(library: try! Library.inMemory())
}
