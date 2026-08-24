import Foundation
import SwiftData

/// A series in the on-device Catalog cache — a template the user can copy into their
/// Library, never a Tracked Series itself (ADR-0002). Written only by `Catalog`, and
/// carrying the `order` the Catalog served it in.
@Model
final class CatalogSeries {
    var externalId: String
    var title: String
    /// What the series is about, as the Catalog describes it.
    var summary: String
    var posterUrl: String?
    var seasons: Seasons
    var order: Int

    init(
        externalId: String,
        title: String,
        summary: String,
        posterUrl: String?,
        seasons: Seasons,
        order: Int
    ) {
        self.externalId = externalId
        self.title = title
        self.summary = summary
        self.posterUrl = posterUrl
        self.seasons = seasons
        self.order = order
    }
}
