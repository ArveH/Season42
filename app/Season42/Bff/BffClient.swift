import Foundation

/// The BFF as the app talks to it, and the only thing that does. One place knows where the
/// server is and one `fetch` does every `GET`, so each endpoint the app uses is a few lines
/// on top of both: today `GET /providers?query=` for the Watch Providers a search matched
/// and `GET /logos/{file}` for the bytes behind one.
///
/// It conforms to the narrow protocols the rest of the app asks through — `LogoSearching`
/// today, more as the BFF grows — so nothing outside this file depends on the client being
/// one thing. This is the only part of the app that touches the network, and so the only
/// part no stub stands in for, which is why it is kept to fetching and decoding: every rule
/// about what a search then does lives beside the feature that asks, where it is tested.
struct BffClient: LogoSearching {
    /// Where the BFF is served from — the one place the app is told that. The build tells
    /// it, through the `BFFBaseURL` key of `Info.plist`: `Config/Bff.xcconfig` commits the
    /// deployed address as the default, and `Config/Local.xcconfig` overrides it for a
    /// build pointed somewhere else, such as a BFF on the developer's own machine.
    ///
    /// The default is committed, so no build is ever asked to supply one and this cannot
    /// fail in a checkout that is intact. What it guards is a broken build — a deleted line
    /// in `Bff.xcconfig` or `Info.plist` — and it says which, because the alternative is an
    /// app whose every search fails for a reason nothing on screen can explain.
    static let defaultBaseUrl: URL = {
        let told = Bundle.main.object(forInfoDictionaryKey: "BFFBaseURL") as? String
        guard let address = told, let url = URL(string: address), url.host() != nil else {
            preconditionFailure(
                "Info.plist carries no usable BFFBaseURL: \(told ?? "the key is missing"). "
                    + "Check BFF_BASE_URL in Config/Bff.xcconfig."
            )
        }
        return url
    }()

    private let baseUrl: URL

    init(baseUrl: URL = BffClient.defaultBaseUrl) {
        self.baseUrl = baseUrl
    }

    func providers(matching text: String) async throws -> [WatchProvider] {
        // `query` is what the BFF calls the text a search is for, so the app spells it
        // the same way wherever it asks.
        var components = URLComponents(
            url: baseUrl.appending(path: "providers"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "query", value: text)]
        guard let url = components?.url else { throw LogoError.notReached }

        // A search asks what the BFF says *now*, so what `URLSession` happens to have
        // kept from the last one is of no use.
        let json = try await fetch(url, ignoringWhatWasCached: true)
        do {
            return try JSONDecoder().decode([WatchProvider].self, from: json)
        } catch {
            // What came back isn't a list of Watch Providers. Which key it tripped over
            // is the BFF's problem, not something the user can act on.
            throw LogoError.notProviders
        }
    }

    func logo(at path: String) async throws -> Data {
        // `/logos/{file}` takes TMDB's path without its leading slash, which is the whole
        // of the translation between the two halves of the BFF's contract (ADR-0008).
        let file = path.hasPrefix("/") ? String(path.dropFirst()) : path

        // Cached bytes are as good as fetched ones here, which is the whole reason the
        // BFF keeps a store of its own: a logo TMDB has published does not change under
        // its own path (ADR-0008). A search asking for twenty of them is why it matters.
        return try await fetch(baseUrl.appending(path: "logos").appending(path: file))
    }

    /// One `GET`, with anything but a `200` treated as nothing having been served.
    private func fetch(_ url: URL, ignoringWhatWasCached: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        if ignoringWhatWasCached {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let answer = response as? HTTPURLResponse else { throw LogoError.notReached }
        guard answer.statusCode == 200 else {
            throw LogoError.notServed(status: answer.statusCode)
        }
        return data
    }
}
