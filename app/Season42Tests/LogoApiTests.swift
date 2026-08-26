import Foundation
import Testing
@testable import Season42

/// Tests the one thing `LogoApi` decides without a network: where the BFF is. That comes
/// from `Info.plist`, fed by `Config/Bff.xcconfig` and overridable in `Local.xcconfig`, so
/// what is asserted here is the wiring rather than a particular address — a developer
/// pointing their build at a local BFF must not turn this red.
struct LogoApiTests {
    @Test func theAppIsToldWhereTheBffIsByItsInfoPlist() throws {
        let told = try #require(
            Bundle.main.object(forInfoDictionaryKey: "BFFBaseURL") as? String
        )

        #expect(LogoApi.defaultBaseUrl == URL(string: told))
    }
}
