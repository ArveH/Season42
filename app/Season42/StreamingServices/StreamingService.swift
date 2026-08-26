import Foundation
import SwiftData

/// One of the services the user has registered as somewhere they watch. Created only
/// through `Library`, which owns every rule about its name — that it is not blank, and
/// that no two services share one.
@Model
final class StreamingService {
    var name: String

    /// The Logo the user has adopted onto this service, as image bytes, or nil where they
    /// have adopted none. Held in the store itself rather than in external storage: a
    /// `w154` logo is a few kilobytes and a user registers a handful of services, so
    /// external storage would buy file management for nothing. Nothing records where the
    /// bytes came from — a Logo is the user's own once adopted, and nothing refreshes it
    /// (ADR-0007).
    var logo: Data?

    /// The Tracked Series that name this service. Deleting the service leaves them naming
    /// none rather than taking them with it (ADR-0006), which is what `.nullify` says.
    @Relationship(deleteRule: .nullify, inverse: \TrackedSeries.streamingService)
    var series: [TrackedSeries] = []

    /// The Tracked Movies that name this service, on the same terms as `series`. There are
    /// two of these because a Library Entry is a way of reading the two kinds together,
    /// not a thing that is stored — so there is no single relationship to hold.
    @Relationship(deleteRule: .nullify, inverse: \TrackedMovie.streamingService)
    var movies: [TrackedMovie] = []

    init(name: String, logo: Data? = nil) {
        self.name = name
        self.logo = logo
    }
}

extension StreamingService {
    /// How many Library Entries name this service: what the Streaming Services tab shows
    /// beside it, and what the delete confirmation counts before it un-sets them.
    var entryCount: Int { series.count + movies.count }
}
