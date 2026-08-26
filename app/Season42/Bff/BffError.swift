import Foundation

/// Why the BFF had nothing to give, whichever of its asks was made. Never the user's mistake to
/// fix — they typed a name, and a server they can't reach is not a name they got wrong — so
/// nothing here is shown verbatim: each search says one thing about a search it couldn't run,
/// and what the user was doing anyway stays open.
enum BffError: Error, Equatable {
    /// No HTTP answer came back at all — the address wouldn't build, or what did come back
    /// isn't an HTTP response.
    case notReached

    /// The server was reached but answered with something other than success. The status is
    /// carried for whoever is reading a log, not for the user: nothing they can do about a
    /// `503` differs from what they can do about a `502`.
    case notServed(status: Int)

    /// The server answered, but what came back isn't what the ask promises. Which key it
    /// tripped over is the BFF's problem, not something the user can act on.
    case notUnderstood
}
