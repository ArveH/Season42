import Foundation
import Testing
@testable import Season42

/// Tests what Copy would write, which is a value the Series Details produces rather than
/// something the detail screen does — so the seasons flatten, the notes it owes the user, and
/// the question it asks before overwriting are all checked here, without a view.
struct SeriesCopyTests {
    // MARK: - What lands in the form

    @Test func aCopyTakesTheNameAndTheOverview() {
        let copy = severance.copy(over: .new)

        #expect(copy.title == "Severance")
        #expect(copy.summary == "Mark leads a team of office workers whose memories have been surgically divided.")
    }

    /// The original name is for telling two similar titles apart on the way in. It is not a
    /// second Title, and the form has nowhere to put it.
    @Test func aCopyLeavesTheOriginalNameBehind() {
        let details = SeriesDetails(
            name: "Money Heist",
            originalName: "La casa de papel",
            overview: "A heist.",
            seasons: [SeriesSeason(seasonNumber: 1, episodeCount: 13)]
        )

        let copy = details.copy(over: .new)

        #expect(copy.title == "Money Heist")
    }

    // MARK: - The seasons flatten

    @Test func theSpecialsAreLeftOut() {
        let copy = severance.copy(over: .new)

        #expect(copy.seasons == [9, 10])
    }

    @Test func aSeasonWithNoEpisodesIsLeftOut() {
        let details = series(seasons: [(1, 10), (2, 8), (3, 0)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [10, 8])
    }

    /// The point of the whole flatten: TMDB's season 4 stays the app's season 4, because the
    /// Position the user keeps is written in TMDB's numbers.
    @Test func aGapIsFilledFromTheNextSurvivingSeasonRatherThanRenumbered() {
        let details = series(seasons: [(1, 10), (2, 8), (4, 6)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [10, 8, 6, 6])
        #expect(copy.seasons.episodeCount(inSeason: 4) == 6)
    }

    /// A season dropped for having no episodes leaves the same gap a missing one does, and it is
    /// filled the same way.
    @Test func aDroppedSeasonLeavesAGapThatIsFilledToo() {
        let details = series(seasons: [(1, 10), (2, 0), (3, 6)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [10, 6, 6])
    }

    /// A run of missing seasons is one fill each, all borrowing from the next season that did
    /// survive — there is nothing else to borrow from.
    @Test func severalMissingSeasonsInARowAreEachFilled() {
        let details = series(seasons: [(1, 10), (4, 6)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [10, 6, 6, 6])
    }

    /// A missing first season is a gap like any other: renumbering it away would move every
    /// season after it.
    @Test func aMissingFirstSeasonIsFilledToo() {
        let details = series(seasons: [(2, 8), (3, 6)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [8, 8, 6])
    }

    /// Nothing is invented past the end: the seasons stop where TMDB's do.
    @Test func nothingIsAddedAfterTheLastSurvivingSeason() {
        let details = series(seasons: [(1, 10), (2, 8), (3, 0)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons.count == 2)
    }

    @Test func specialsAloneCountAsNothingSurviving() {
        let details = series(seasons: [(0, 5)])

        let copy = details.copy(over: .new)

        #expect(copy.seasons == [1])
    }

    /// A series announced but not aired still copies what it does know.
    @Test func aSeriesWithNoAiredSeasonsStillCopiesItsTitleAndDescription() {
        let details = SeriesDetails(
            name: "Not Yet",
            originalName: "Not Yet",
            overview: "Announced, and nothing more.",
            seasons: []
        )

        let copy = details.copy(over: .new)

        #expect(copy.title == "Not Yet")
        #expect(copy.summary == "Announced, and nothing more.")
        #expect(copy.seasons == [1])
    }

    // MARK: - What it tells the user

    /// An answer the app can hold as it stands invents nothing, so there is nothing to say.
    @Test func anAnswerThatNeededNothingDoneToItSaysNothing() {
        let details = series(seasons: [(1, 10), (2, 8)])

        let copy = details.copy(over: .new)

        #expect(copy.notes.isEmpty)
    }

    @Test func droppedSpecialsAreStated() {
        let copy = severance.copy(over: .new)

        #expect(copy.notes.contains(.droppedSpecials(episodes: 3)))
    }

    @Test func aDroppedSeasonWithNoEpisodesIsStated() {
        let details = series(seasons: [(1, 10), (2, 0)])

        let copy = details.copy(over: .new)

        #expect(copy.notes.contains(.droppedSeasonWithoutEpisodes(season: 2)))
    }

    @Test func aFilledSeasonSaysWhoseCountItBorrowed() {
        let details = series(seasons: [(1, 10), (3, 6)])

        let copy = details.copy(over: .new)

        #expect(copy.notes.contains(.filledSeason(season: 2, episodes: 6, borrowedFrom: 3)))
    }

    @Test func aSeriesWithNoAiredSeasonsSaysSo() {
        let details = series(seasons: [])

        let copy = details.copy(over: .new)

        #expect(copy.notes == [.noSeasonsAired])
    }

    /// Every invention has a sentence to show — a note the screen could not word is a note the
    /// user never reads.
    @Test func everyNoteSaysItself() {
        let details = series(seasons: [(0, 3), (1, 10), (3, 6), (4, 0)])

        let copy = details.copy(over: SeriesFormContents(
            title: "",
            summary: "",
            seasons: .newSeriesPlaceholder,
            position: Position(season: 9, episode: 1)
        ))

        #expect(copy.notes.count == 4)
        #expect(copy.notes.allSatisfy { !$0.text.isEmpty })
    }

    // MARK: - What it does about the Position

    @Test func aPositionTheCopiedSeasonsHaveIsNotMentioned() {
        let details = series(seasons: [(1, 10), (2, 8)])
        let form = SeriesFormContents(
            title: "",
            summary: "",
            seasons: .newSeriesPlaceholder,
            position: Position(season: 2, episode: 3)
        )

        let copy = details.copy(over: form)

        #expect(copy.notes.isEmpty)
    }

    @Test func aPositionPastTheCopiedSeasonsSaysWhereItWouldLand() {
        let details = series(seasons: [(1, 10), (2, 8)])
        let form = SeriesFormContents(
            title: "",
            summary: "",
            seasons: .newSeriesPlaceholder,
            position: Position(season: 4, episode: 20)
        )

        let copy = details.copy(over: form)

        #expect(copy.notes.contains(
            .movesPosition(from: Position(season: 4, episode: 20), to: Position(season: 2, episode: 8))
        ))
    }

    /// A form with nothing watched has no Position to move, so there is nothing to say about
    /// one.
    @Test func aFormWithNothingWatchedHasNoPositionToMove() {
        let details = series(seasons: [(1, 1)])

        let copy = details.copy(over: .new)

        #expect(copy.notes.isEmpty)
    }

    /// What the form says after the sheet has closed, so a Position that moved out of sight is
    /// still said somewhere the user is looking.
    @Test func aCopyCarriesWhereThePositionWouldLand() {
        let details = series(seasons: [(1, 10), (2, 8)])
        let form = SeriesFormContents(
            title: "",
            summary: "",
            seasons: .newSeriesPlaceholder,
            position: Position(season: 4, episode: 20)
        )

        let copy = details.copy(over: form)

        #expect(copy.movedPosition == Position(season: 2, episode: 8))
    }

    @Test func aCopyThatMovesNothingCarriesNoPosition() {
        let details = series(seasons: [(1, 10), (2, 8)])

        #expect(details.copy(over: .new).movedPosition == nil)
    }

    /// The wording is the promise ADR-0011 makes, so it is pinned rather than merely present.
    @Test func aFilledSeasonSaysInWordsWhatItBorrowedAndFromWhere() {
        let text = SeriesCopyNote.filledSeason(season: 2, episodes: 6, borrowedFrom: 3).text

        #expect(text.contains("no Season 2"))
        #expect(text.contains("6 episodes"))
        #expect(text.contains("borrowed from Season 3"))
    }

    @Test func oneBorrowedEpisodeIsNotSaidAsOneEpisodes() {
        let text = SeriesCopyNote.filledSeason(season: 2, episodes: 1, borrowedFrom: 3).text

        #expect(text.contains("as 1 episode borrowed"))
    }

    /// A moved Position says both ends of the move: where it was is what makes the sentence
    /// mean anything.
    @Test func aMovedPositionSaysWhereItCameFromAndWhereItGoes() {
        let text = SeriesCopyNote.movesPosition(
            from: Position(season: 4, episode: 20),
            to: Position(season: 2, episode: 8)
        ).text

        #expect(text.contains("S4E20"))
        #expect(text.contains("S2E8"))
    }

    // MARK: - Asking before it overwrites

    @Test func copyingIntoAFreshFormAsksNothing() {
        #expect(severance.copy(over: .new).overwritesTheForm == false)
    }

    @Test func aTitleAlreadyTypedIsWorthAsking() {
        let form = SeriesFormContents(title: "Severence", summary: "", seasons: .newSeriesPlaceholder, position: nil)

        #expect(severance.copy(over: form).overwritesTheForm)
    }

    @Test func aDescriptionAlreadyTypedIsWorthAsking() {
        let form = SeriesFormContents(title: "", summary: "The one about the office.", seasons: .newSeriesPlaceholder, position: nil)

        #expect(severance.copy(over: form).overwritesTheForm)
    }

    @Test func seasonsOtherThanThePlaceholderAreWorthAsking() {
        let form = SeriesFormContents(title: "", summary: "", seasons: [10, 10], position: nil)

        #expect(severance.copy(over: form).overwritesTheForm)
    }

    /// One season still, but not the ten episodes it opened with: that count is the user's own.
    @Test func aCorrectedEpisodeCountIsWorthAsking() {
        let form = SeriesFormContents(title: "", summary: "", seasons: [12], position: nil)

        #expect(severance.copy(over: form).overwritesTheForm)
    }

    /// A Position is not something Copy writes, so it is not something Copy asks about — it says
    /// where the Position would land instead.
    @Test func aPositionAloneIsNotWorthAsking() {
        let form = SeriesFormContents(
            title: "",
            summary: "",
            seasons: .newSeriesPlaceholder,
            position: Position(season: 1, episode: 4)
        )

        #expect(severance.copy(over: form).overwritesTheForm == false)
    }

    @Test func whitespaceAloneIsNotSomethingTheUserTyped() {
        let form = SeriesFormContents(title: "  ", summary: "\n", seasons: .newSeriesPlaceholder, position: nil)

        #expect(severance.copy(over: form).overwritesTheForm == false)
    }

    // MARK: - What the stub answers with

    private var severance: SeriesDetails {
        SeriesDetails(
            name: "Severance",
            originalName: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided.",
            seasons: [
                SeriesSeason(seasonNumber: 0, episodeCount: 3),
                SeriesSeason(seasonNumber: 1, episodeCount: 9),
                SeriesSeason(seasonNumber: 2, episodeCount: 10),
            ]
        )
    }

    private func series(seasons: [(Int, Int)]) -> SeriesDetails {
        SeriesDetails(
            name: "A Series",
            originalName: "A Series",
            overview: "What it is about.",
            seasons: seasons.map { SeriesSeason(seasonNumber: $0.0, episodeCount: $0.1) }
        )
    }
}
