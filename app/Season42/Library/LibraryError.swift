import Foundation

/// Why the Library refused to store something. Every case is a user-fixable mistake,
/// so each carries a message the UI can show as-is.
enum LibraryError: Error, Equatable, LocalizedError {
    case titleIsBlank
    case seriesHasNoSeasons
    case seasonHasNoEpisodes(season: Int)
    case positionOutOfRange(Position)

    var errorDescription: String? {
        switch self {
        case .titleIsBlank:
            "Give the series a title."
        case .seriesHasNoSeasons:
            "A series needs at least one season."
        case .seasonHasNoEpisodes(let season):
            "Season \(season) needs at least one episode."
        case .positionOutOfRange(let position):
            "\(position.shorthand) is outside the seasons and episodes entered for this series."
        }
    }
}
