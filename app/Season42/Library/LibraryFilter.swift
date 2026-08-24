import Foundation

/// How the user has narrowed the Library listing: a search text matched against titles,
/// a Status, and a kind of Library Entry. Each part is optional and they combine — an
/// entry has to satisfy every part that is set. An untouched filter narrows nothing.
struct LibraryFilter: Equatable {
    /// Matched against the title, ignoring case, accents and surrounding whitespace.
    var searchText: String = ""

    /// Only Tracked Series carry a Status, so setting one narrows the listing to series.
    var status: WatchStatus?

    /// Series or movies only, or nil for both.
    var kind: LibraryEntry.Kind?

    /// Whether the user has narrowed anything at all — what the Library tab keys its
    /// "your filter hides everything" wording off.
    var isNarrowing: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || status != nil
            || kind != nil
    }

    /// Whether `entry` satisfies every part of the filter that is set.
    func matches(_ entry: LibraryEntry) -> Bool {
        matchesSearchText(entry) && matchesStatus(entry) && matchesKind(entry)
    }

    private func matchesSearchText(_ entry: LibraryEntry) -> Bool {
        let searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return true }
        return entry.title.range(
            of: searchText,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private func matchesStatus(_ entry: LibraryEntry) -> Bool {
        guard let status else { return true }
        guard case .series(let series) = entry else { return false }
        return series.status == status
    }

    private func matchesKind(_ entry: LibraryEntry) -> Bool {
        kind == nil || kind == entry.kind
    }
}
