import UIKit
import Testing
@testable import Season42

/// The attribution TMDB's terms require under a search: the mark is bundled rather than
/// fetched, so it draws with the BFF down, and the wording says what the terms say.
struct TmdbAttributionTests {
    @Test func theMarkIsBundledSoItDrawsOffline() {
        #expect(UIImage(named: TmdbAttribution.markName) != nil)
    }

    @Test func theWordingSaysWhereTheDataComesFrom() {
        #expect(TmdbAttribution.wording.contains("provided by TMDB"))
    }

    @Test func theWordingCarriesTheSentenceTheTermsRequire() {
        #expect(TmdbAttribution.wording.contains("uses the TMDB API but is not endorsed or certified by TMDB"))
    }
}
