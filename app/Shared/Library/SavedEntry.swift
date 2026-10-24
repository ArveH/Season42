import Foundation

/// What saving a Library Entry from a sheet came to: the entry as stored, and whether the
/// Streaming Service the user picked for it was gone by then.
struct SavedEntry<Entry> {
    let entry: Entry
    /// Set when the picked service was deleted on another device while the sheet was open,
    /// so the entry was saved without one; nil otherwise.
    let serviceDeletedElsewhere: ServiceDeletedElsewhere?
}

/// A Library Entry saved without the Streaming Service the user picked, because an iCloud
/// sync brought in that service's deletion while the sheet was open (ADR-0024). The entry is
/// left as ADR-0006's nullify rule would have left it, and the user is told once the sheet
/// has closed.
struct ServiceDeletedElsewhere: Equatable {
    let serviceName: String
    let entryTitle: String

    /// What the user is told, as-is.
    var message: String {
        "\(serviceName) was deleted on another device, so \(entryTitle) was saved without a Streaming Service."
    }
}
