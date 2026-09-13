import Foundation

/// Which build of the app the user is running, as the About section says it. The support page
/// asks people to report a problem and cannot ask them which build they are on, so the app has
/// to be the one that tells them. Named for the build rather than the release because a
/// Release Slot is a different idea already: this says nothing about when anything airs.
///
/// Both numbers are the build's own — `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, which
/// Xcode writes into the generated `Info.plist` as `CFBundleShortVersionString` and
/// `CFBundleVersion`. Nothing here decides them; this only reads them, which is why it reads
/// an info dictionary rather than a `Bundle`: the running app's is `AppBuild.main`, and a test
/// hands it whatever dictionary the case is about, missing keys included.
///
/// A missing key is a broken build rather than anything the user can act on, so it reads as
/// `unknown` and the rest of Settings still draws. `BffClient.defaultBaseUrl` stops the app
/// dead over a missing key because a search that silently fails has no other explanation; a
/// version the user was going to quote in an email does not earn that.
struct AppBuild {
    /// What a number the build did not supply reads as.
    static let unknown = "—"

    /// The running app's own.
    static let main = AppBuild(info: Bundle.main.infoDictionary ?? [:])

    let version: String
    let build: String

    init(info: [String: Any]) {
        version = info["CFBundleShortVersionString"] as? String ?? Self.unknown
        build = info["CFBundleVersion"] as? String ?? Self.unknown
    }

    /// The version with the build beside it, which is the one thing a bug report needs.
    var label: String { "\(version) (\(build))" }
}
