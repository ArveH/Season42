# How long an image is kept is a setting, capped at six months

[TMDB's API Terms of Use](https://www.themoviedb.org/api-terms-of-use), section 1.C, restricts a
caller from being able to:

> Cache, for longer than 6 months, any information obtained through or from TMDB or the TMDB APIs.

The Logo Store and the Poster Store are caches by the plain reading of that verb: keyed on TMDB's
own identifiers, refilled from TMDB on a miss, existing solely so that a hit costs no TMDB call.
Both said in as many words that nothing in them expired, which put them outside the clause.

**How long an image is kept is `Tmdb:ImageLifetimeDays`, and it defaults to one day.** The clause
is the ceiling on that setting, not the policy: anything configured above 170 days is clamped to
it, so no deployment can be configured out of the terms, and a value of zero keeps nothing at all.

**The ceiling is 170 days rather than the 181 the clause literally allows, because what has to fit
inside the clause is the lifetime plus a sweep's lag.** An image nobody asks for again is reached
only by the daily sweep, so at a ceiling of 181 days such an image could sit for 182. The shortest
six calendar months there are come to 181 days; 170 leaves that margin several times over, and
nobody choosing a retention window is choosing between 170 days and 180.

**A day, because a store is worth exactly the fetches it saves.** With the user count this server
has, the same logo or poster is rarely asked for twice in a week, so a long lifetime buys almost
nothing and keeps someone else's pictures on a volume for no reason. The saving a store exists for
is real within a single session — a search sheet asks for twenty logos at once, and a poster is
asked for about twice per adoption — and that is a matter of minutes, not months. Raising the
setting is how this changes when traffic makes the longer saving real, and it is one number in
`appsettings.json` rather than a deploy of new code.

**The age of a stored image is when it was written, and nothing else is recorded.** The file's own
timestamp is the whole of it — no sidecar, no index, no field added to the snapshot. It is on disk,
so it is not lost to a restart, and it does not advance because the server was up or reset because
it was not. It also means a change to the setting applies to what is already stored, immediately
and without a migration: the limit is read at each comparison, never baked into the files.

**Both halves are needed, and they answer different questions.** The stores refuse to serve an aged
image, deleting it as they find it, which is what makes "never served past the limit" true at every
moment rather than true between sweeps. A daily sweep walks both directories and removes what has
aged, which is what reaches an image nobody asks for again — the one the read path would never
look at. Neither alone satisfies the clause: lazily-only would retain an unasked-for image
forever, and timer-only would serve an aged image for up to a day.

**The sweep runs as the server starts and every 24 hours after that**, beside the provider refresh
that already runs on that cadence. Starting with a sweep rather than waiting out the first tick is
what makes the limit independent of the machine staying up: a machine that was stopped for the
whole lifetime evicts the moment it is back, and this one is a Fly machine that stops when nobody
is asking ([ADR-0015](0015-the-bff-moves-to-fly-io.md)).

**The first sweep is started and not waited for, unlike the refresh's first fetch.** The refresh is
awaited because a server with no snapshot answers `503` to a question it exists to answer; nothing
answers differently for a sweep not yet finished, because the read path refuses an aged image on
its own. On a machine that stops whenever nobody is asking, waiting would put a walk of both stores
into the cold start every user pays for, to no end.

**An aged image goes whether or not the fetch that would replace it succeeds.** The read path
deletes first and fetches second, so a TMDB that is down gets a `502` rather than the stale bytes.
Serving them would be keeping an image past the limit for exactly as long as the outage lasts,
which is not this server's decision to make.

**The snapshot is not swept.** `watch-providers.json` is not an image, it is rewritten daily by
the refresh, and sweeping it would mean deleting the last good snapshot during a long TMDB outage
— turning a degraded service into a dead one for no gain the clause asks for. The sweep is scoped
to `logos/` and `posters/`.

## What this changes about ADR-0008 and ADR-0012

Both of those say the store they describe never expires, and
[ADR-0008](0008-the-snapshot-is-the-allowlist-for-a-logo-store.md) rejects giving the logo store an
expiry outright. **This decision overrides that sentence in both and nothing else in either.** The
arguments those ADRs actually turn on are about *keying* — the snapshot as an allowlist, the id
rather than the path — and a limit on how long a keyed file is kept leaves every one of them
standing.

ADR-0008's rejection of expiry was argued on staleness alone: TMDB's logo path is
content-addressed in practice, so re-fetching buys bytes that are identical by construction. That
reasoning was correct and is still correct. It is simply not the reason this eviction exists. This
one is not about the bytes going stale; it is about a term in someone else's contract and about
what a store is actually worth, and no argument about whether the bytes changed can answer either.

## Considered Options

- **A hard-coded six months, the clause read as the policy.** Rejected, and this ADR said the
  opposite in its first draft, so the reversal is worth stating plainly: six months is the longest
  the terms allow, which is a different question from how long is worth keeping. Answering the
  second with the first keeps every image for the maximum permitted period by default, which is
  the most retention of someone else's data this server could lawfully have, chosen by nobody. A
  ceiling and a default are two numbers, and only one of them is TMDB's to set.
- **A setting with no ceiling.** Rejected: it makes compliance a thing a deployment has to get
  right, and the failure is silent — a server configured to a year looks exactly like one
  configured to a week. The clamp costs one `Math.Clamp` and makes the clause hold whatever is in
  the environment.
- **Lazily as files are touched, and nothing else.** Rejected: it satisfies "never serves" and
  fails "does not retain". A logo for a provider that left the snapshot, or a poster for a series
  nobody searches for twice, is never touched again and would sit there indefinitely — which is
  exactly the case the clause is about.
- **On a timer, and nothing else.** Rejected: between one sweep and the next, an image that has
  aged is still served. With a one-day lifetime that window is the lifetime itself, which would
  make the limit mean roughly half what it says, and the check that closes it is a comparison of
  two timestamps on a file the read path has already found.
- **Await the first sweep, as the refresh's first fetch is awaited.** Rejected: it buys a
  guarantee that is already held. The two are not alike — a snapshot that has never been fetched
  changes what `/providers` answers, while a sweep that has not been round changes nothing anyone
  can observe.
- **Record a fetch time beside each file, or in an index.** Rejected: it is a second source of
  truth for something the filesystem already records, and one that can disagree with the bytes it
  describes — a file restored, copied or half-written leaves the index saying something the file
  does not. `mtime` is written by the same operation that writes the bytes, and it is what lets a
  changed setting apply to what is already on disk.
- **Delete the whole store directory on a schedule.** Rejected: it is a limit read as a calendar.
  Every image's age would be measured from the last purge rather than from its own fetch, so an
  image fetched the day before a purge would be dropped a day later, and the cost lands in one
  spike rather than spread across when each was fetched.
- **Revalidate with `ETag` instead of evicting.** Rejected: it answers a staleness question that
  nobody asked here. A conditional request that comes back `304` leaves the bytes on disk, which
  is the very thing the clause forbids past six months.

## Consequences

The two stores no longer promise permanence, and the doc comments that said they did are corrected
rather than quietly left. `LogoStore`, `PosterStore` and the Logo Store and Poster Store entries in
`CONTEXT.md` all say what is now true: a hit costs no TMDB call, and an image costs one fetch per
lifetime rather than one for the life of the store.

At the default, the store is a within-session saving rather than a standing one, and the TMDB
traffic is correspondingly higher than a long lifetime would give: an image still being looked at
costs a fetch a day, and a poster's costs the details call beside it. That is the trade this
default is choosing, at a volume where the absolute numbers are small, and the setting is there
for when they are not.

The setting is the first thing to reach for if TMDB's rate limit is ever the binding constraint —
before any caching cleverness, because the store already exists and this only changes how long it
is allowed to work.

A poster that TMDB has re-postered since is picked up at the next eviction. ADR-0012 accepted
serving the first poster it saw indefinitely and named "delete the directory" as the escape; at the
default that escape is now taken daily, which makes the staleness it tolerated very nearly
impossible to observe.

Eviction is where the "nothing here is the user's" promise gets tested and holds: what an evicted
image costs is a fetch. Everything the user actually owns is bytes on the device, adopted and kept
there ([ADR-0013](0013-a-poster-is-adopted-as-bytes-and-no-tmdb-id-is-kept.md),
[ADR-0007](0007-a-bff-fetches-provider-logos-the-app-keeps-the-bytes.md)), and nothing on the
server's side of that line is anything a user would miss.

**This decision is about the server and says nothing about the device.** Whether an adopted Poster
or Logo — held with no TMDB id beside it, refreshed by nothing, arrived at by a user's own search —
is a cache within the meaning of 1.C at all is a separate question, and one to be put to TMDB
rather than answered here.
