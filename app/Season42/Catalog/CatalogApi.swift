import Foundation

/// The Catalog API as the app talks to it: one `GET /catalog`, decoded into a snapshot.
/// This is the only part of Sync that touches the network, and so the only part no stub
/// stands in for — which is why it is kept to fetching and decoding, and why every rule
/// about what a Sync then does lives in `Catalog`, where it is tested.
struct CatalogApi: CatalogFetching {
    /// Where the Catalog is served from — the one place the app is told where the API is.
    /// The default is the API's local development address (the `http` profile in
    /// `api/Season42.Api/Properties/launchSettings.json`), which is what a simulator
    /// reaches on the machine running it.
    static let defaultBaseUrl = URL(string: "http://localhost:5265")!

    private let baseUrl: URL

    init(baseUrl: URL = CatalogApi.defaultBaseUrl) {
        self.baseUrl = baseUrl
    }

    func fetchSnapshot() async throws -> CatalogSnapshot {
        // A Sync is a request for what the Catalog says *now*, so what URLSession happens
        // to have kept from the last one is of no use: it is the cache on the device that
        // this is being fetched to replace.
        var request = URLRequest(url: baseUrl.appending(path: "catalog"))
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (json, response) = try await URLSession.shared.data(for: request)

        guard let answer = response as? HTTPURLResponse else { throw CatalogError.notACatalog }
        guard answer.statusCode == 200 else {
            throw CatalogError.notServed(status: answer.statusCode)
        }
        do {
            return try CatalogSnapshot(json: json)
        } catch {
            // What came back isn't a Catalog. Which key it tripped over is the API's
            // problem, not something the user can act on, so it isn't carried further.
            throw CatalogError.notACatalog
        }
    }
}
