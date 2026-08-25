import Testing
@testable import Season42

struct AppTabTests {
    @Test func tabsAreWatchingThenLibraryInOrder() {
        #expect(AppTab.allCases == [.watching, .library])
    }

    @Test func watchingIsTheHomeTab() {
        #expect(AppTab.allCases.first == .watching)
    }

    @Test(arguments: AppTab.allCases)
    func everyTabHasATitle(tab: AppTab) {
        #expect(!tab.title.isEmpty)
    }
}
