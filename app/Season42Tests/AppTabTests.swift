import Testing
@testable import Season42

struct AppTabTests {
    @Test func tabsAreWatchingThenLibraryThenStreamingServicesThenSettingsInOrder() {
        #expect(AppTab.allCases == [.watching, .library, .streamingServices, .settings])
    }

    @Test func watchingIsTheHomeTab() {
        #expect(AppTab.allCases.first == .watching)
    }

    @Test func settingsIsTheLastTab() {
        #expect(AppTab.allCases.last == .settings)
    }

    @Test(arguments: AppTab.allCases)
    func everyTabHasATitle(tab: AppTab) {
        #expect(!tab.title.isEmpty)
    }

    @Test(arguments: AppTab.allCases)
    func everyTabHasAnIcon(tab: AppTab) {
        #expect(!tab.systemImage.isEmpty)
    }
}
