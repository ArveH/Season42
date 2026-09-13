import Foundation
import Testing

/// The privacy manifest the app ships (ADR-0021). It is a file nothing in the app reads, so
/// nothing but a test notices when it stops being shipped or stops saying what it says — and
/// what it says is an answer given to Apple at every submission. The tests are hosted in the
/// app, so `Bundle.main` here is the app bundle that would be submitted.
struct PrivacyManifestTests {
    /// Reading it off the bundle rather than off the repo is the whole point: a manifest that
    /// is in the source tree but not in the built app declares nothing to anyone.
    private static func manifest() throws -> [String: Any] {
        let url = try #require(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "the app bundle ships no PrivacyInfo.xcprivacy"
        )
        let contents = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url),
            format: nil
        )
        return try #require(contents as? [String: Any], "the manifest is not a dictionary")
    }

    /// Absent means nothing is declared, which is a thing the manifest can legitimately say —
    /// so a missing key reads as an empty list rather than failing here.
    private static func accessedAPITypes() throws -> [[String: Any]] {
        try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
    }

    @Test func theBuiltAppShipsIt() throws {
        _ = try Self.manifest()
    }

    /// Everything the app knows is entered by hand and kept on the device, so there is no
    /// collected data type to declare and no tracking to admit to. Saying so is the point of
    /// the file: an empty list is an answer, and a missing key is a question left open.
    @Test func itCollectsNothingAndTracksNobody() throws {
        let manifest = try Self.manifest()

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect(manifest["NSPrivacyTrackingDomains"] as? [String] == [])
        let collected = manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        #expect(collected?.isEmpty == true)
    }

    /// `UserDefaults` is the one required-reason API family the app reaches for — the
    /// Appearance setting and the Watching Order are kept in it — and `CA92.1` is the
    /// "access info from the app itself" reason, which is the only way this app uses it.
    @Test func itDeclaresUserDefaultsAccessedForTheAppsOwnInformation() throws {
        let accessed = try Self.accessedAPITypes()

        let defaults = try #require(
            accessed.first { $0["NSPrivacyAccessedAPIType"] as? String
                == "NSPrivacyAccessedAPICategoryUserDefaults" },
            "the manifest declares no UserDefaults access"
        )
        #expect(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    /// The manifest is a list of everything, not of some things, so a family that turns up
    /// here without a decision behind it is the thing worth failing on. Today that is one.
    @Test func itDeclaresNothingElse() throws {
        let accessed = try Self.accessedAPITypes()

        #expect(accessed.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
            == ["NSPrivacyAccessedAPICategoryUserDefaults"])
    }
}
