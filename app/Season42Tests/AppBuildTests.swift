import Foundation
import Testing
@testable import Season42

/// Which build the user is on, as the About section says it. The support page asks people to
/// report a problem, and this is the only way they can say which build they are reporting.
struct AppBuildTests {
    @Test func itReadsTheVersionAndBuildOffAnInfoDictionary() {
        let build = AppBuild(info: [
            "CFBundleShortVersionString": "2.0",
            "CFBundleVersion": "14",
        ])

        #expect(build.version == "2.0")
        #expect(build.build == "14")
    }

    @Test func theLabelIsTheVersionWithTheBuildBesideIt() {
        let build = AppBuild(info: [
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "37",
        ])

        #expect(build.label == "1.2 (37)")
    }

    /// A build with either key missing is a broken build rather than something the user can
    /// act on, so the row says it has nothing to say and the rest of Settings still draws.
    @Test func aMissingKeyReadsAsUnknownRatherThanEmpty() {
        let build = AppBuild(info: [:])

        #expect(build.version == AppBuild.unknown)
        #expect(build.build == AppBuild.unknown)
        #expect(build.label == "\(AppBuild.unknown) (\(AppBuild.unknown))")
    }

    /// The app this test runs inside is the one the About section reads, so the real bundle
    /// answering at all is worth asserting: the keys are the build's to generate.
    @Test func theAppsOwnBundleAnswersWithBoth() {
        #expect(AppBuild.main.version != AppBuild.unknown)
        #expect(AppBuild.main.build != AppBuild.unknown)
    }
}
