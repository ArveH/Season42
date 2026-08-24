import Foundation
import SwiftData

/// A streaming service in the on-device Catalog cache.
///
/// Like every cached entry it carries the `order` it was served in: the Catalog decides
/// how it reads, and the cache is a copy of the Catalog rather than a listing of its own.
/// Cached entries are written only by `Catalog`, and only ever wholesale.
@Model
final class CatalogStreamingService {
    var externalId: String
    var name: String
    var order: Int

    init(externalId: String, name: String, order: Int) {
        self.externalId = externalId
        self.name = name
        self.order = order
    }
}
