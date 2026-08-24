import Foundation
import SwiftData

/// A movie in the on-device Catalog cache, on the same template terms as a Catalog Series
/// but without seasons. Written only by `Catalog`, and carrying the `order` the Catalog
/// served it in.
@Model
final class CatalogMovie {
    var externalId: String
    var title: String
    /// What the movie is about, as the Catalog describes it.
    var summary: String
    var posterUrl: String?
    var order: Int

    init(externalId: String, title: String, summary: String, posterUrl: String?, order: Int) {
        self.externalId = externalId
        self.title = title
        self.summary = summary
        self.posterUrl = posterUrl
        self.order = order
    }
}
