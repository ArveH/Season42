import SwiftUI
import Testing
@testable import Season42

/// The Appearance choice: offered as System, Light and Dark, applied at the root, and
/// remembered between launches outside the Library (ADR-0005).
@MainActor
struct AppSettingsTests {
    @Test func appearanceOffersSystemThenLightThenDark() {
        #expect(Appearance.allCases == [.system, .light, .dark])
    }

    @Test(arguments: Appearance.allCases)
    func everyAppearanceHasALabel(appearance: Appearance) {
        #expect(!appearance.label.isEmpty)
    }

    @Test func systemFollowsTheDeviceAndLightAndDarkOverrideIt() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }

    @Test func systemIsTheDefaultUntilTheUserChooses() throws {
        let defaults = try TestDefaults()

        let settings = AppSettings(defaults: defaults.suite)

        #expect(settings.appearance == .system)
    }

    @Test func aChoiceSurvivesARelaunch() throws {
        let defaults = try TestDefaults()
        let settings = AppSettings(defaults: defaults.suite)

        settings.appearance = .dark
        let relaunched = AppSettings(defaults: defaults.suite)

        #expect(relaunched.appearance == .dark)
    }

    @Test func choosingSystemAgainIsRememberedToo() throws {
        let defaults = try TestDefaults()
        let settings = AppSettings(defaults: defaults.suite)
        settings.appearance = .light

        settings.appearance = .system
        let relaunched = AppSettings(defaults: defaults.suite)

        #expect(relaunched.appearance == .system)
    }

    @Test func aChoiceTheAppNoLongerKnowsFallsBackToSystem() throws {
        let defaults = try TestDefaults()
        defaults.suite.set("sepia", forKey: AppSettings.appearanceKey)

        let settings = AppSettings(defaults: defaults.suite)

        #expect(settings.appearance == .system)
    }

    @Test func theChoiceIsKeptInDefaultsNotTheLibrary() throws {
        let defaults = try TestDefaults()
        let settings = AppSettings(defaults: defaults.suite)

        settings.appearance = .dark

        #expect(defaults.suite.string(forKey: AppSettings.appearanceKey) == "dark")
    }
}
