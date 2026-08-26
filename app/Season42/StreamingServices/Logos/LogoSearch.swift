import Foundation

/// A search for a Logo, and everything the naming sheet is holding while it runs: the
/// name being typed, the Logo adopted so far, and where the search has got to. Every
/// decision about a search lives here — that a blank field searches for nothing, that an
/// empty answer is not a failure, that adopting a result fills in its name too — so the
/// sheet renders this and decides nothing, and all of it is tested against a stub.
///
/// Nothing here reaches a store. What the user ends up with is handed back when they
/// save, and `Library` is what decides whether it may be kept.
@MainActor
@Observable
final class LogoSearch {
    /// Where a search has got to. The two ways of coming back with no Logo to show are
    /// separate cases because they call for different actions: one is "try another name",
    /// the other is "the server isn't there, save without one".
    enum State: Equatable {
        /// Nothing has been searched for yet, or the field has been left alone since.
        case idle

        /// A search is in flight. What the sheet spins on.
        case searching

        /// What the search matched, in the order the BFF served them.
        case results([WatchProviderMatch])

        /// The search ran and nothing matched the text.
        case matchedNothing

        /// The search couldn't be run at all — the BFF is unreachable, or answered with
        /// something that isn't a list of Watch Providers.
        case failed
    }

    /// The name the user is typing, which is both what a search searches for and what is
    /// saved. Adopting a result fills it in; it stays editable afterwards, so "Netflix
    /// (family)" with the Netflix logo is what a rename away from the adopted name is.
    var name: String

    /// The Logo bytes the user has adopted, or nil where they have adopted none. Set by
    /// adopting a result and cleared by `removeLogo()`, and untouched by everything else:
    /// a search that is run and abandoned leaves the Logo the sheet opened with.
    private(set) var logo: Data?

    private(set) var state: State = .idle

    private let logos: any LogoSearching

    /// - Parameters:
    ///   - name: what the name field starts out holding — nothing for a new service, the
    ///     current name for one being renamed.
    ///   - logo: the Logo the service already carries, so renaming one opens with it and
    ///     saving leaves it alone unless the user changes it.
    init(name: String, logo: Data? = nil, logos: any LogoSearching) {
        self.name = name
        self.logo = logo
        self.logos = logos
    }

    /// Whether there is a Logo to draw and so a Remove affordance to offer. Adopting one
    /// by mistake would otherwise mean deleting the service to be rid of it, which
    /// un-sets every Library Entry naming it.
    var hasLogo: Bool { logo != nil }

    /// Searches for what is typed. A blank field does nothing at all rather than erroring
    /// — there is no mistake in not having typed yet — and leaves whatever the last search
    /// left on screen.
    ///
    /// Never throws: a search that can't be run is a state the sheet shows inline, not
    /// something that stops the user saving. Saving is open throughout, because a
    /// Streaming Service with no Logo is entirely valid.
    func search() async {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        state = .searching
        do {
            let providers = try await logos.providers(matching: text)
            guard !providers.isEmpty else {
                state = .matchedNothing
                return
            }
            state = .results(await matches(for: providers))
        } catch {
            state = .failed
        }
    }

    /// Adopts a result: its logo becomes the Logo and its name fills in the field, both
    /// still the user's to change. The results stay on screen, so adopting the wrong one
    /// of two similar names is a second tap rather than a second search.
    ///
    /// A match the BFF wouldn't serve an image for adopts its name and no Logo. That is
    /// the honest outcome — there are no bytes to adopt — and the Remove affordance
    /// simply doesn't appear.
    func adopt(_ match: WatchProviderMatch) {
        name = match.name
        logo = match.logo
    }

    /// Clears the adopted Logo and leaves the name alone: the two are the user's to set
    /// apart, and a name typed by hand is not a thing a wrong logo should take with it.
    func removeLogo() {
        logo = nil
    }

    /// Each provider with its logo fetched, asked for together rather than one after the
    /// other — a search matches up to twenty, and the BFF serves all but the first ask
    /// for any one of them off its own store (ADR-0008). The BFF's order is kept, because
    /// it is TMDB's display priority and the app has nothing better to sort by.
    private func matches(for providers: [WatchProvider]) async -> [WatchProviderMatch] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask { [logos] in
                    (index, try? await logos.logo(at: provider.logoPath))
                }
            }

            var fetched: [Int: Data?] = [:]
            for await (index, logo) in group {
                fetched[index] = logo
            }
            return providers.enumerated().map { index, provider in
                WatchProviderMatch(provider: provider, logo: fetched[index] ?? nil)
            }
        }
    }
}
