import Foundation
import SwiftData

/// One thing the user tracks, whichever kind it is. The Library tab lists series and
/// movies together, so this is what it lists; nothing else in the app needs the union.
enum LibraryEntry: Identifiable {
    case series(TrackedSeries)
    case movie(TrackedMovie)

    var id: PersistentIdentifier {
        switch self {
        case .series(let series): series.persistentModelID
        case .movie(let movie): movie.persistentModelID
        }
    }

    var title: String {
        switch self {
        case .series(let series): series.title
        case .movie(let movie): movie.title
        }
    }

    var addedAt: Date {
        switch self {
        case .series(let series): series.addedAt
        case .movie(let movie): movie.addedAt
        }
    }
}
