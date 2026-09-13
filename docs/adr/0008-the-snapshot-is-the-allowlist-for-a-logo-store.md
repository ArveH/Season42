# The snapshot is the allowlist for a logo store that never expires

> **The title is no longer true of the second half, and is kept as the decision was taken.** The
> store does expire now — nothing in it is kept past six months, because TMDB's terms say so
> ([ADR-0020](0020-the-image-stores-keep-nothing-past-six-months.md)). Everything below about the
> snapshot as the allowlist, and about how the store is keyed, stands unchanged.

The BFF serves the logo images themselves. `GET /logos/{file}` looks in a local store first; on a
miss it fetches the image from TMDB's image host at size `w154`, writes it into the store, and
returns it. `{file}` is a `logoPath` from `/providers` without its leading slash, so the two halves
of the endpoint contract fit together with nothing in between to translate them.

**The current snapshot is the allowlist, and it is consulted before anything touches the
filesystem.** A `{file}` no Watch Provider in the snapshot names is refused there and then. This is
the whole of the path validation: there is no sanitizer, no `..` check, no filename pattern. Path
traversal is refused because `../../appsettings.json` is not a path any Watch Provider publishes,
which is the same reason `madeup.jpg` is refused. A route that turns a caller's string into a
filesystem path is a way to read arbitrary files off the server unless something stops it, and the
thing that stops it here is a list this server already had.

The store needs no invalidation, because a logo that has been published does not change under its
own path. Between one fetch of a logo and the next, TMDB is asked for it at most once — including
across restarts, and including two simultaneous asks for the same missing logo.

> **Amended by [ADR-0020](0020-the-image-stores-keep-nothing-past-six-months.md).** This paragraph
> read "the store never expires" and the rejected option below rejected giving it one. Both are
> now wrong on that one point: nothing is kept past six months, because TMDB's terms say so. The
> staleness argument here — a published logo does not change under its own path, so re-fetching
> buys identical bytes — was never wrong and is not what ADR-0020 answers. Everything this ADR
> decides about *keying* stands unchanged.

The distinction ADR-0007 drew for searches is carried here: before any snapshot exists the answer
is `503`, not `404`. "I do not know yet" and "no such logo" are different answers, and collapsing
them would make a BFF that has never reached TMDB indistinguishable from one that has and found
nothing.

## Considered Options

- **Hand the app TMDB's image URL and let it fetch the bytes itself.** Rejected: the image host
  needs no token, so this is not a credentials problem — it is a seam problem. ADR-0007's line is
  that the app never talks to TMDB, and buying one saved hop with a second exception to that costs
  the clarity of the rule. It would also make TMDB's CDN layout — the base URL, the size names, the
  path scheme — the app's business, so a change to any of it becomes an App Store release rather
  than a deploy.
- **Let the app pass the URL to fetch and have the BFF get it.** Rejected outright: that is an open
  proxy. Every server on the network the BFF can reach becomes reachable through it, and the
  allowlist that makes the real design safe is exactly what this option throws away.
- **Proxy each ask straight through to TMDB, storing nothing.** Rejected: a search sheet asks for
  twenty logos at once, and every one of them would be a round trip to TMDB for bytes that never
  change, counted against a rate limit shared with the searches that matter.
- **Give the store an expiry, or revalidate with `ETag`.** Rejected: it buys re-fetching bytes that
  are identical by construction. TMDB's logo path is content-addressed in practice — a rebranded
  provider arrives in the snapshot under a new path, not with new bytes under the old one — so
  expiry is a cost with no failure mode to protect against.
  _Overtaken by [ADR-0020](0020-the-image-stores-keep-nothing-past-six-months.md): the store does
  have an expiry now, and this option was answering the wrong question. It weighs staleness, and
  the reason an expiry exists is a term in TMDB's contract, which no argument about whether the
  bytes changed can answer._
- **Serve several sizes, `/logos/{size}/{file}`.** Rejected: one size, chosen against how rows draw
  logos, is the requirement; the rest is generality for a caller that does not exist. It would also
  widen the part of the route that has to be checked, and the argument above is worth keeping
  narrow — one segment, one allowlist.
- **Validate the path with string rules: reject `..`, require a filename pattern.** Rejected: a
  sanitizer is a denylist of the shapes someone thought of, and it is a second rule sitting beside
  the real one. The snapshot already enumerates every path this server has any business serving.
  Checking against it makes traversal not a special case that was handled but a string that was
  never a member, and it decides without going near the disk.
- **Key the stored files by provider id, or by a hash of the name.** Rejected: TMDB's path is
  already a key, unique and stable. Anything else is a mapping to maintain, and ADR-0007 threw the
  provider id away on the way in for reasons that have not changed.

## Consequences

The store directory holds two kinds of thing now — `watch-providers.json` and `logos/` — and both
are still a cache of someone else's data. Deleting it costs fetches and nothing else, which is what
ADR-0007 promised about it.

`w154` is baked into the bytes on disk rather than recorded beside them. Changing the size is
therefore not a migration but a deletion: empty `logos/` and let it fill again. This is the right
trade at a few kilobytes a logo, and it is why the size is stated in one place in the code rather
than threaded through the store as a parameter.

The BFF now holds two clients to TMDB: an authenticated one for the API and an unauthenticated one
for the image host. The token goes only on the calls that need it, so an image fetch cannot leak it
to a CDN edge.

A logo stops being served the moment its provider leaves the snapshot, even though its bytes are
still on disk. That is the allowlist working as intended rather than a bug to fix, and it costs the
user nothing: by ADR-0007 an adopted logo already lives on the device as bytes, so the only thing
that becomes unavailable is adopting that logo anew.

The app-side half — searching, adopting a logo onto a Streaming Service, and storing the bytes on
the device — is deliberately not part of this decision.

## Note: this governs the logo route, not every store behind an image

The snapshot-as-allowlist argument above is about `/logos/{file}` and holds for it unchanged. It
is not the general rule for this server's images, and it is not what makes
`/series/{id:int}/poster` safe: there is no snapshot of posters for it to be consulted against.
That route is safe because a poster is asked for by id and never by a path, so there is nothing
caller-supplied for the allowlist to have to catch — see
[ADR-0012](0012-a-poster-is-asked-for-by-id-and-the-store-keys-on-it.md), which also takes the
opposite key for its store and says why the two differ.
