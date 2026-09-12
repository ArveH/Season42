# A caller gets a share of the BFF, not all of it

Every BFF route that can reach TMDB is behind a fixed-window rate limit of 60 requests per minute,
partitioned by the calling client's address. A caller over the limit gets `429` with a `Retry-After`
and a problem body saying why. `/health` is not behind it.

The reason is that this repository is public, and the address
`https://season42-bff.fly.dev` is committed in it ([ADR-0015](0015-the-bff-moves-to-fly-io.md),
`app/Config/Bff.xcconfig`). Before, the hostname was as private as the repository holding it and the
server's only caller was one phone. Now anyone who reads the repository has the address of a server
that will search TMDB for them, with no account and no key, on somebody else's token.

**Nothing leaks, and that is the distinction this decision rests on.** The whole point of the BFF is
that the token stays on the machine ([ADR-0007](0007-a-bff-fetches-provider-logos-the-app-keeps-the-bytes.md)):
it goes out in an `Authorization` header to TMDB and reaches no caller, so an open server is not a
disclosed credential. What an open server is instead is a free TMDB proxy, and what it spends is
TMDB's per-token allowance and the Fly machine's waking hours. The limit is about the bill and the
allowance, not about secrecy — which is why it is a limit and not an API key.

## Why no key, which would have been stricter

A shared key the app carries is a key shipped inside an iOS app, which anyone willing to unzip an
`.ipa` can read. It would buy real protection against the casual reader of this repository and none
at all against anyone who wanted the token's throughput, in exchange for a secret in the build, a
rotation story, and a class of failure where the app stops searching for reasons the user cannot
act on. The limit costs one file and refuses the same casual reader.

## What the numbers are, and why they are not tighter

60 requests per minute is far above what the app does and far below what a script wants. The app's
heaviest moment is a search: one `/series` call, one `/series/{id}` when a match is opened, one
`/series/{id}/poster` after that. Typing into a search field is a handful more. A user cannot reach
60 in a minute by using the app; a loop reaches it in under a second.

The window is fixed rather than sliding because a fixed window is the cheapest thing that answers
the question, and the burst a window boundary permits — up to 120 requests across two adjacent
windows — is still not a quantity worth engineering against.

Nothing queues. `QueueLimit` is zero, so a caller over the limit is refused rather than held: a
queued search is one whose answer arrives after the user has given up, and a queue on a machine that
stops when nobody is searching is memory held for exactly the caller it should not be held for.

## The partition is the caller, and what that does not cover

The key is `Fly-Client-IP`, the header fly-proxy puts the real client's address in, falling back to
the connection's own address where there is no proxy — a local `dotnet run`, or the test host. The
header is not spoofable from outside: fly-proxy overwrites whatever a caller sent, so a request
arriving with one carries the proxy's word.

**Many callers at once are many buckets, and this decision does not defend against that.** A
distributed caller gets a full share each, and the limit does nothing. Defending against it needs a
global cap as well as a per-caller one, and a global cap is a decision with a real cost — it lets a
stranger's traffic exhaust the app's own share, turning somebody else's abuse into this user's
broken search. That is worse than the thing it prevents for a personal app with one user, so it was
not taken. If the Fly bill or TMDB's allowance ever says otherwise, a chained global limiter is
where to look, and this is the paragraph that was wrong.

## Why `/health` is outside it

Fly's health check is not a caller. A `429` to the probe is a machine Fly restarts, so a limit
applied there would cause outages rather than prevent them — and it would do so precisely when the
server was already under load. This is the same reasoning ADR-0010 gave for the probe answering for
the host and never for the snapshot: the probe's job is to say whether this machine should keep
serving, and a rate limit is not an answer to that.

The exemption is a partition of its own rather than a route-by-route opt-in, and the key it uses
cannot collide with any caller's, because a partitioned limiter builds one limiter per key and keeps
it: a shared key would hand whichever arrived first to both, and the probe would inherit a limit or
a caller would escape one.

## Consequences

- A route added to the BFF is behind the limit without anything being said, because the limiter is
  global with one exemption rather than an opt-in per route. That arrangement, rather than a test,
  is what covers a new route: `RateLimitingTests` walks a hand-written list of today's routes and
  would not notice one added to `Program.cs` and not to it. The list is worth having anyway — it is
  what says the global limiter really does reach all eight — but it is not a guard.
- A request that never reaches TMDB still costs a permit — a query-less `/series`, or a `/logos`
  path the snapshot does not name. Making the cheap refusals free would make them the way in.
- The limit is one machine's. It is per-process state, so the count is per machine — which is
  exactly right while there is one machine, and the second item `fly.toml` now names on the list to
  revisit before `fly scale count` goes above 1.
