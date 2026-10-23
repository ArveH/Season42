/// The two ways the Watching listing can be ordered, at the user's choice (ADR-0014). The
/// raw value is what the choice is remembered as between launches, so a case is not renamed
/// lightly.
enum WatchingOrder: String, CaseIterable {
    /// Most recently watched first — the order for working down what the user is mid-way
    /// through.
    case lastWatched

    /// Alphabetical — the order for finding one series among many.
    case title

    /// What the segmented control calls it.
    var label: String {
        switch self {
        case .lastWatched: "Last watched"
        case .title: "Title"
        }
    }
}
