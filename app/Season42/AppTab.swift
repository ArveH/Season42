/// The app's top-level tabs, in tab-bar order. Watching is the home tab.
enum AppTab: CaseIterable {
    case watching
    case library
    case catalog

    var title: String {
        switch self {
        case .watching: "Watching"
        case .library: "Library"
        case .catalog: "Catalog"
        }
    }

    var systemImage: String {
        switch self {
        case .watching: "play.circle"
        case .library: "books.vertical"
        case .catalog: "square.grid.2x2"
        }
    }
}
