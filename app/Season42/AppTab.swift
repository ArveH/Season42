/// The app's top-level tabs, in tab-bar order. Watching is the home tab, and Settings the
/// last: it is about the app rather than about anything the user tracks.
enum AppTab: CaseIterable {
    case watching
    case library
    case streamingServices
    case settings

    var title: String {
        switch self {
        case .watching: "Watching"
        case .library: "Library"
        case .streamingServices: "Streaming Services"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .watching: "play.circle"
        case .library: "books.vertical"
        case .streamingServices: "tv"
        case .settings: "gearshape"
        }
    }
}
