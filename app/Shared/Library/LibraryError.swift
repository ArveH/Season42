import Foundation

/// Why the Library refused to store something. Every case is a user-fixable mistake,
/// so each carries a message the UI can show as-is.
enum LibraryError: Error, Equatable, LocalizedError {
    case seriesTitleIsBlank
    case movieTitleIsBlank
    case seriesHasNoSeasons
    case seasonHasNoEpisodes(season: Int)
    case positionOutOfRange(Position)
    case streamingServiceNameIsBlank
    case streamingServiceAlreadyExists(name: String)

    var errorDescription: String? {
        switch self {
        case .seriesTitleIsBlank:
            "Give the series a title."
        case .movieTitleIsBlank:
            "Give the movie a title."
        case .seriesHasNoSeasons:
            "A series needs at least one season."
        case .seasonHasNoEpisodes(let season):
            "Season \(season) needs at least one episode."
        case .positionOutOfRange(let position):
            "\(position.shorthand) is outside the seasons and episodes entered for this series."
        case .streamingServiceNameIsBlank:
            "Give the streaming service a name."
        case .streamingServiceAlreadyExists(let name):
            "There is already a streaming service called \(name)."
        }
    }
}
