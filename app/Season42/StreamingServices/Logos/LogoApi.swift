import Foundation

/// The BFF as the app talks to it: `GET /providers?search=` for the matches and
/// `GET /logos/{file}` for the bytes behind one. This is the only part of searching for a
/// Logo that touches the network, and so the only part no stub stands in for — which is
/// why it is kept to fetching and decoding, and why every rule about what a search then
/// does lives in `LogoSearch`, where it is tested.
struct LogoApi: LogoSearching {
    /// Where the BFF is served from — the one place the app is told that. The default is
    /// the BFF's local development address (the `http` profile in
    /// `bff/Season42.Bff/Properties/launchSettings.json`), which is what a simulator
    /// reaches on the machine running it.
    static let defaultBaseUrl = URL(string: "http://localhost:5265")!

    private let baseUrl: URL

    init(baseUrl: URL = LogoApi.defaultBaseUrl) {
        self.baseUrl = baseUrl
    }

    func providers(matching text: String) async throws -> [WatchProvider] {
        var components = URLComponents(
            url: baseUrl.appending(path: "providers"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "search", value: text)]
        guard let url = components?.url else { throw LogoError.notProviders }

        let json = try await fetch(url)
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
        return try await fetch(baseUrl.appending(path: "logos").appending(path: file))
    }

    /// One `GET`, with anything but a `200` treated as nothing having been served. A
    /// search asks what the BFF says *now*, and the bytes it answers with are about to be
    /// adopted, so what `URLSession` happens to have kept is of no use either way.
    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let answer = response as? HTTPURLResponse else { throw LogoError.notProviders }
        guard answer.statusCode == 200 else {
            throw LogoError.notServed(status: answer.statusCode)
        }
        return data
    }
}
