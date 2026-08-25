/// The app's top-level tabs, in tab-bar order. Watching is the home tab.
enum AppTab: CaseIterable {
    case watching
    case library

    var title: String {
        switch self {
        case .watching: "Watching"
        case .library: "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .watching: "play.circle"
        case .library: "books.vertical"
        }
    }
}
