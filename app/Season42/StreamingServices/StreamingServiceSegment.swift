import SwiftUI

/// The one place a row draws where its Library Entry is watched. The Watching tab's
/// series row and both Library rows use it, so where the Streaming Service reads one way
/// it reads that way everywhere — and there is a single place to change when it is to
/// show more than a name.
///
/// The segment owns the `·` that precedes it, because an entry naming no service must
/// leave no separator behind. The rest of a subtitle is still one joined string, and a row
/// appends `text` to it so the whole subtitle stays a single run of text: that is what
/// keeps wrapping and truncation exactly as they were.
struct StreamingServiceSegment: View {
    /// Where the entry is watched, or nil when the user has named nowhere.
    let service: StreamingService?

    var body: some View { text }

    /// The same drawing as a `Text`, for a row that has the rest of a subtitle to join it to.
    var text: Text {
        guard let service else { return Text(verbatim: "") }
        return Text(verbatim: " · \(service.name)")
    }
}
