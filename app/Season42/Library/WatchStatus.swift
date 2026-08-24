/// The five explicit, user-set states of a Tracked Series. Nothing here is derived —
/// the app never infers a status from Position, dates, or the Catalog.
enum WatchStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case watching
    case waiting
    case finished
    case dropped

    var title: String {
        switch self {
        case .planned: "Planned"
        case .watching: "Watching"
        case .waiting: "Waiting"
        case .finished: "Finished"
        case .dropped: "Dropped"
        }
    }
}
