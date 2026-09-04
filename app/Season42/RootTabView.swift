import SwiftUI

struct RootTabView: View {
    let library: Library
    let settings: AppSettings

    var body: some View {
        TabView {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    switch tab {
                    case .watching: WatchingView(library: library)
                    case .library: LibraryView(library: library)
                    case .streamingServices: StreamingServicesView(library: library)
                    case .settings: SettingsView(settings: settings)
                    }
                }
            }
        }
        // Applied here, at the root, so every tab and every sheet over one draws the same
        // way; nil hands the choice back to the device.
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}

#Preview {
    RootTabView(
        library: try! Library.inMemory(),
        settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!)
    )
}
