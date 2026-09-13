import UIKit
import Testing
@testable import Season42

/// The attribution TMDB's terms require under a search: the mark is bundled rather than
/// fetched, so it draws with the BFF down, and the wording says what the terms say —
/// including, word for word, the sentence the terms dictate.
struct TmdbAttributionTests {
    /// TMDB's current sentence, spelled out here rather than read off the component, so a
    /// drift in the component is a failure rather than a test that agrees with it.
    private let required =
        "This product uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB."

    @Test func theMarkIsBundledSoItDrawsOffline() {
        #expect(UIImage(named: TmdbAttribution.markName) != nil)
    }

    @Test(arguments: TmdbAttribution.Credits.allCases)
    func everyWordingCarriesTheSentenceTheTermsRequire(_ credits: TmdbAttribution.Credits) {
        #expect(credits.wording.hasSuffix(required))
    }

    @Test func theSearchSheetsSayTheDetailsAndPostersAreTmdbs() {
        #expect(TmdbAttribution.Credits.seriesAndMovies.wording.contains("provided by TMDB"))
    }

    @Test func theLogoSheetCreditsJustWatchForTheProviderData() {
        let wording = TmdbAttribution.Credits.watchProviders.wording
        #expect(wording.contains("JustWatch"))
        #expect(wording.contains("logos"))
    }
}
