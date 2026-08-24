# Season42

An iPhone app for tracking which series and movies one person watches across streaming services. User data lives on the device; a small API serves shared catalog data.

## Language

**Catalog**:
The shared, read-only pool of series, movies, and streaming services served by the API. Identical for every installation; never contains personal data.
_Avoid_: system data, common data

**Catalog Series / Catalog Movie**:
A template entry in the Catalog. Tracking one copies it into the user's data; the copy is thereafter independent.

**Catalog Snapshot**:
The whole Catalog as one served document — what `GET /catalog` returns, and the very same file the app bundles to fill its cache from on a first launch (ADR-0003). A snapshot is decoded and cached, never stored as-is; filling from one replaces everything cached.
_Avoid_: catalog dump, seed data, fixture

**Already Tracked**:
A Catalog Series or Catalog Movie the Library already holds one of, which the Catalog tab marks so the same thing isn't tracked twice by accident. A copy keeps no reference back to the entry it came from (ADR-0002), so title and kind are the whole of the test: a hand-entered entry marks the Catalog entry it duplicates, and a copy the user renamed no longer does.
_Avoid_: linked, imported, owned

**Library**:
The user's own collection of Tracked Series and Tracked Movies. Lives only on the device; does not include the cached Catalog.
_Avoid_: user data, my shows, collection

**Library Entry**:
One thing in the Library, whichever kind it is — a Tracked Series or a Tracked Movie. What the Library tab lists, searches, filters and deletes; outside the Library nothing treats the two as one.
_Avoid_: item, record

**Library Filter**:
How the user has narrowed the Library listing: a search text matched against titles, a Status, and a kind of Library Entry (series or movies). The parts combine, and an untouched filter narrows nothing. Because only a Tracked Series has a Status, filtering by one leaves no movies in the listing.
_Avoid_: query, search criteria

**Tracked Series**:
A series the user has added to their own data — hand-entered or copied from the Catalog — including seasons, episode counts, and their watch position.
_Avoid_: show, subscription, my series

**Tracked Movie**:
A movie in the user's data. Carries only a watched/unwatched state (a watchlist entry is simply an unwatched Tracked Movie), held as `isWatched`. Marking one watched stamps the date; un-marking corrects the state and leaves the stamp alone, as un-watching an episode of a Tracked Series does.

**Description**:
The user's own free-text note on what a Tracked Series or Tracked Movie is about. Carried in code as `summary`, because SwiftData reserves the name `description`.
_Avoid_: synopsis, blurb, notes

**Status**:
Where a Tracked Series stands, as one of exactly five values the user sets by hand — Planned, Watching, Waiting, Finished, Dropped. Never derived from Position, dates, or the Catalog.
_Avoid_: state, watch state

**Position**:
The season and episode of a Tracked Series the user has most recently watched.
_Avoid_: progress, bookmark

**Watched At**:
The moment the user last marked an episode of a Tracked Series watched. Stamped by each advance of the Position, and the sole basis for the Watching tab's "most recently watched" order. An un-watch corrects the Position but leaves the stamp alone. Carried in code as `lastWatchedAt`. A Tracked Movie has the same idea in `watchedAt`: when it was last marked watched, likewise untouched by an un-mark.
_Avoid_: last seen, watch history

**Next Episode Date**:
A user-entered, optional date on a Tracked Series recording when the next episode becomes available. Not derived from the Catalog.

**Streaming Service**:
A label on a Tracked Series or Tracked Movie recording where the user watches it. Says nothing about global availability.
_Avoid_: channel, platform, provider

**Sync**:
Replacing the device's cached Catalog with the API's current contents. Never touches Tracked Series or Tracked Movies. A Sync happens two ways, and which one it is decides only what the user is shown: one the user asked for on the Catalog tab shows that it is running and reports a failure, and a **Quiet Sync** — the one every launch starts — shows neither. Both replace the cache whole, an empty Catalog included; neither leaves a half-replaced one.
_Avoid_: refresh, import

**Quiet Sync**:
The Sync a launch starts without being asked. Nobody is waiting on it, so it is invisible: no progress, and a failure keeps whatever is cached — the bundled snapshot on a first launch — and is not reported. An API that can't be reached is the ordinary case, not an error the user has anything to do about.
_Avoid_: background sync, auto-refresh
