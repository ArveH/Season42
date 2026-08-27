import Foundation
import Testing
@testable import Season42

/// Tests the copy seam for a movie: what Copy would write into the form, and when it asks
/// first. Far less to test than a series' copy, and that is the point — a movie has no seasons,
/// so nothing is dropped, nothing is invented, and there is no note the user is owed.
@MainActor
struct MovieCopyTests {
    // MARK: - What copying writes

    @Test func copyingTakesTheTitleAndTheOverview() {
        let copy = arrival.copy(over: .new)

        #expect(copy.title == "Arrival")
        #expect(copy.summary == arrival.overview)
    }

    /// TMDB's own title, not the one the user mistyped into the form.
    @Test func copyingReplacesATitleTheUserGotWrong() {
        let copy = arrival.copy(over: MovieFormContents(title: "Arival", summary: ""))

        #expect(copy.title == "Arrival")
    }

    /// A movie TMDB carries no overview for copies an empty Description rather than refusing:
    /// the title is what the user came for, and the Description is theirs to write.
    @Test func copyingAMovieWithNoOverviewCopiesAnEmptyDescription() {
        let copy = MovieDetails(title: "Quiet", originalTitle: "", overview: "").copy(over: .new)

        #expect(copy.title == "Quiet")
        #expect(copy.summary.isEmpty)
    }

    /// The original title is what tells two similar titles apart on the screen. It is not what
    /// the user is tracking, so it never reaches the form.
    @Test func copyingNeverTakesTheOriginalTitle() {
        let copy = arrival.copy(over: .new)

        #expect(copy.title != arrival.originalTitle)
    }

    // MARK: - When copying asks first

    @Test func copyingIntoAFreshFormDoesNotAsk() {
        #expect(arrival.copy(over: .new).overwritesTheForm == false)
    }

    @Test func copyingOverATypedTitleAsks() {
        let form = MovieFormContents(title: "Arival", summary: "")

        #expect(arrival.copy(over: form).overwritesTheForm)
    }

    @Test func copyingOverATypedDescriptionAsks() {
        let form = MovieFormContents(title: "", summary: "The one with the squid language.")

        #expect(arrival.copy(over: form).overwritesTheForm)
    }

    /// Whitespace is not something the user typed and would miss.
    @Test func copyingOverNothingButWhitespaceDoesNotAsk() {
        let form = MovieFormContents(title: "   ", summary: "\n ")

        #expect(arrival.copy(over: form).overwritesTheForm == false)
    }

    /// The Streaming Service and the watched state are the user's alone, and a copy leaves them
    /// alone — so having set them is not a reason to be asked about a copy that cannot touch
    /// them. `MovieFormContents` holds neither, which is what makes that true by construction.
    @Test func aCopyCarriesNothingButTheTitleAndTheDescription() {
        let copy = arrival.copy(over: .new)

        #expect(copy == MovieCopy(title: "Arrival", summary: arrival.overview, overwritesTheForm: false))
    }

    private var arrival: MovieDetails {
        MovieDetails(
            title: "Arrival",
            originalTitle: "Arrival (original)",
            overview: "An expert linguist is recruited by the military to determine whether the "
                + "visitors come in peace or are a threat."
        )
    }
}
