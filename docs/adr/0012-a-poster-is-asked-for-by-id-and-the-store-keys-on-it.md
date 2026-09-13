# A poster is asked for by id, and the store keys on it

The BFF serves posters. `GET /series/{id:int}/poster` and `GET /movies/{id:int}/poster` look in a
local store first; on a miss the route asks TMDB for that entry's details, reads the poster path
out of them, fetches the image from TMDB's image host at size `w342`, writes it into the store
under the id, and returns it. Both details payloads carry `hasPoster`, so the app knows whether
there is anything to ask for before it asks.

Taken for series first and extended to movies unchanged, which is what the id key made cheap:
everything below is written of both, and the one thing the second route added is the paragraph
after next.

**A poster is asked for by id, never by a TMDB path.** The app never sees a poster path — the
details payload carries a yes or a no, not the path — so there is no caller-supplied path to
escape from. That is the whole of this route's validation: the route reads an `int`, and nothing
a caller says ever becomes part of a filesystem path.

This is deliberately a *different* answer from the one the logo route gives. `/logos/{file}` is
safe because the current snapshot is a bounded allowlist consulted before the filesystem is
touched ([ADR-0008](0008-the-snapshot-is-the-allowlist-for-a-logo-store.md)). There is no snapshot
of posters, and no bounded set for one to be taken of: a region publishes a few dozen watch
providers, while TMDB knows a poster for very nearly every series there is. That mechanism does
not extend here, so this route needs its own. Two routes, two arguments; neither is the general
rule.

**The store keys on the id, unlike the logo store, which keys on the path TMDB published.** With
no snapshot to resolve an id against, keying on the path would mean spending a details call on
every hit just to learn what the file is called — and a store that costs a TMDB call per hit is
not a store. Keyed on the id, a hit costs no TMDB call at all, and only a miss pays
details-then-image.

**The id is only half the key: the store keys on the kind of thing as well.** TMDB numbers its
series and its movies in separate keyspaces, so 550 names one of each and their posters must not
stand in for one another. The store keeps them in `posters/series/` and `posters/movies/`, spelled
as the two routes are, and the id means what it means inside one of them.

A poster can go stale where a logo cannot, and the difference is the id key again. The logo store's
bytes cannot: a rebranded provider arrives under a new path and the old path keeps meaning what it
always meant. A poster kept under a series id can — TMDB re-posters a returning series, and this
store will go on serving the poster it first saw. That is accepted rather than unnoticed. A poster
is a picture of a series, not a fact about it, and the app is about to keep whichever one the user
adopted as bytes of its own anyway; the escape, if a stale one ever matters, is the same one
ADR-0007 promised for the whole store — delete the directory and let it fill again.

> **Amended by [ADR-0020](0020-image-lifetime-is-a-setting-capped-at-six-months.md).** This paragraph
> opened "Nothing expires" and the one below it takes the same line about a remembered negative.
> A poster is kept for as long as the deployment says now — a day by default — and never longer
> than TMDB's terms allow anything obtained from them to be cached. The staleness reading above
> stands as written — it is why a stale poster is tolerable, not why one is eventually dropped —
> and so does everything this ADR decides about the key. One side effect: the "delete the
> directory" escape is now taken automatically, as often as the lifetime says.

Nothing negative is remembered either: a poster is fetched about twice per adoption rather than
once per render, so a remembered "no" would save almost nothing and would go on being wrong about
a series that has since gained one.

One poster size, `w342`, as a single committed constant beside the logo's `w154` — so what the
user looks at is what they keep.

## Considered Options

- **Key the store on TMDB's poster path, as the logo store does.** Rejected: it is the same key
  only in appearance. The logo store can use the path because `/providers` already handed the app
  that path and the snapshot already holds it; nothing hands the app a poster path, and nothing
  holds one. Every hit would have to buy the key back with a details call, which is the cost the
  store exists to avoid.
- **Answer the poster path in the details payload and let the app ask for `/posters/{file}`.**
  Rejected: it puts a caller-supplied path back into a filesystem route, and then needs an
  allowlist to make that safe — an allowlist there is no snapshot to build. It would also make
  TMDB's path scheme the app's business, which is the objection ADR-0008 already made about
  handing the app TMDB's image URL.
- **Take a snapshot of posters, so the allowlist mechanism reaches here too.** Rejected: a
  snapshot of every series TMDB knows is a different order of thing from a snapshot of one
  region's watch providers, and it would be stale for exactly the series a user is likely to be
  searching for — the one that only just aired.
- **Remember that a series has no poster.** Rejected: the ask is rare per series, so a negative
  buys back a call the user was unlikely to make twice, and it is the one kind of answer that
  changes on its own. `hasPoster` in the details payload already spares the app the ask, which is
  where the saving actually was.
- **Serve the poster from the details call the app just made, as bytes in the payload.** Rejected:
  a search sheet reads details for the one match the user opened, but posters are drawn for rows
  the user has not opened. Bytes in a JSON payload also cannot be cached by anything between here
  and the app, and cannot be asked for a second time without asking for everything else again.
- **Several sizes, `/series/{id}/poster/{size}`.** Rejected for the reason ADR-0008 rejected it
  for logos: one size, chosen against how the app draws it, is the requirement, and a size a
  caller names is a wider route than a size this server committed to.

## Consequences

The store directory holds three kinds of thing now — `watch-providers.json`, `logos/` and
`posters/`, the last split by kind into `series/` and `movies/` — and all three are still a cache
of someone else's data. Deleting it costs fetches and
nothing else, which is what ADR-0007 promised about it.

The posters the first version of this store wrote — flat, at `posters/{id}.jpg`, before the kind
was part of the key — are not read any more and not moved. They are a cache of someone else's
data, so what they cost is the fetches that fill `posters/series/` again, and deleting `posters/`
is the same escape it has always been. Writing a migration for a directory whose whole promise is
that losing it costs only fetches would be the more expensive answer.

`w342` is baked into the bytes on disk rather than recorded beside them, as `w154` is for logos.
Changing the size is a deletion of `posters/` rather than a migration — and so, for the same
directory, is picking up a series' new poster.

`hasPoster` says what TMDB's answer said, not that a fetch will succeed. A series can advertise a
poster whose image the host then refuses, and that is a `502` like any other TMDB failure: the app
draws its placeholder for a `hasPoster` of false, and has to survive a poster that will not arrive
in either case.

A miss costs two TMDB calls where a logo's costs one, and the extra one is on the authenticated
API rather than the public image host. This is the price of the id key, and it is paid once per
entry per stretch the poster is kept for — once for the life of the store as this was written, and
once per configured lifetime since ADR-0020.

The gates that make two simultaneous asks cost one fetch are reclaimed here, where the logo
store's are kept. The logo store's keys come from the snapshot and so are bounded by it; a poster's
key is whatever integer a caller sent, and a dictionary that only ever grew would be a way to
spend this server's memory by asking about ids that do not exist.

`hasPoster` is the only thing TMDB's poster path becomes on its way to the app. The path itself
stops here, as the provider id did in ADR-0007 and the TMDB id does in
[ADR-0002](0002-catalog-entries-are-templates.md).

The app-side half — drawing a poster and keeping it — is deliberately not part of this decision.
It is taken in [ADR-0013](0013-a-poster-is-adopted-as-bytes-and-no-tmdb-id-is-kept.md).
