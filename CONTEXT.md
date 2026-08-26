# Season42

An iPhone app for tracking which series and movies one person watches across streaming services. Everything the app knows is the user's own, entered by hand and stored on the device.

## Language

**Library**:
The user's own collection of Tracked Series and Tracked Movies — everything the app stores, and the only place a series or a movie is held (ADR-0005). Lives only on the device.
_Avoid_: user data, my shows, collection

**Library Entry**:
One thing in the Library, whichever kind it is — a Tracked Series or a Tracked Movie. What the Library tab lists, searches, filters and deletes; outside the Library nothing treats the two as one.
_Avoid_: item, record

**Library Filter**:
How the user has narrowed the Library listing: a search text matched against titles, a Status, and a kind of Library Entry (series or movies). The parts combine, and an untouched filter narrows nothing. Because only a Tracked Series has a Status, filtering by one leaves no movies in the listing.
_Avoid_: query, search criteria

**Tracked Series**:
A series the user has entered into the Library, including seasons, episode counts, and their watch position. "Tracked" is what marks it out from the series the user has merely heard of: it is one they chose to keep.
_Avoid_: show, subscription, my series

**Tracked Movie**:
A movie the user has entered into the Library. Carries only a watched/unwatched state (a watchlist entry is simply an unwatched Tracked Movie), held as `isWatched`. Marking one watched stamps the date; un-marking corrects the state and leaves the stamp alone, as un-watching an episode of a Tracked Series does.

**Description**:
The user's own free-text note on what a Tracked Series or Tracked Movie is about. Carried in code as `summary`, because SwiftData reserves the name `description`.
_Avoid_: synopsis, blurb, notes

**Status**:
Where a Tracked Series stands, as one of exactly five values the user sets by hand — Planned, Watching, Waiting, Finished, Dropped. Never derived from Position or dates.
_Avoid_: state, watch state

**Position**:
The season and episode of a Tracked Series the user has most recently watched.
_Avoid_: progress, bookmark

**Watched At**:
The moment the user last marked an episode of a Tracked Series watched. Stamped by each advance of the Position, and the sole basis for the Watching tab's "most recently watched" order. An un-watch corrects the Position but leaves the stamp alone. Carried in code as `lastWatchedAt`. A Tracked Movie has the same idea in `watchedAt`: when it was last marked watched, likewise untouched by an un-mark.
_Avoid_: last seen, watch history

**Next Episode Date**:
A user-entered, optional date on a Tracked Series recording when the next episode becomes available.

**Streaming Service**:
One of the services the user has registered, kept as a list they add to, rename and delete
themselves. A Tracked Series or Tracked Movie names at most one of them as where the user
watches it, and names the service itself rather than a copy of its name, so renaming one
renames it everywhere it is named. An entry may name none. Says nothing about global
availability: it is where this user watches, not where the thing can be watched.
_Avoid_: channel, platform, provider, label

**Watch Provider**:
A service TMDB knows of, with a name and a logo. Lives in the BFF only, in a daily snapshot of one
region's providers, and is never stored by the app: it is what a search offers, not a thing the
user owns. A Streaming Service is what the user registers; a Watch Provider is where the picture on
it may have come from, and the two part company the moment the user renames one (ADR-0007).
_Avoid_: streaming service, provider logo, TMDB service

**Logo Store**:
Where the BFF keeps the logo images it has fetched, one file per Watch Provider logo under the
path TMDB published it at. It fills itself: the first ask for a logo fetches it from TMDB, every
ask after that is served from the store, and nothing in it expires, because a logo TMDB has
published does not change under its own path. The current snapshot is what it will serve — a path
no Watch Provider names is refused before the store is touched at all, which is the whole of the
route's path validation (ADR-0008). Like the snapshot beside it, it holds nothing the user owns:
deleting it costs fetches.
_Avoid_: logo cache, image proxy
