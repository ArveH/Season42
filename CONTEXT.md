# Season42

An iPhone app for tracking which series and movies one person watches across streaming services. Everything the app knows is the user's own, entered by hand and stored on the device.

## Language

**Library**:
The user's own collection of Tracked Series and Tracked Movies — everything the app stores, and the only place a series or a movie is held (ADR-0005). Lives only on the device, and a store the app can no longer open is discarded and started again empty rather than taking the launch with it (ADR-0009).
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
themselves, and optionally carrying a Logo. A Tracked Series or Tracked Movie names at most
one of them as where the user watches it, and names the service itself rather than a copy of
its name, so renaming one renames it everywhere it is named. An entry may name none. Says
nothing about global availability: it is where this user watches, not where the thing can be
watched.
_Avoid_: channel, platform, provider, label

**Logo**:
The image the user has adopted onto a Streaming Service, held on it as bytes. Once adopted it
is theirs: renaming the service does not disturb it, and nothing ever refreshes it — which is
why nothing is remembered about where it came from (ADR-0007). A service may carry none. A
Library Entry's row draws the Logo where its service has one and the service's name where it
has not; where a Logo slot is drawn regardless — as beside the name in the Streaming Services
tab — the `tv` symbol in secondary grey stands in for a Logo that isn't there.
_Avoid_: icon, artwork, provider logo, image

**Watch Provider**:
A service TMDB knows of, with a name and a logo. Kept in the BFF, in a daily snapshot of one
region's providers, and never stored by the app: it reaches the app only as a search result to be
offered, and is gone the moment the sheet closes. It is what a search offers, not a thing the user
owns. A Streaming Service is what the user registers; a Watch Provider is where the picture on
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

**Series Match**:
A series a search matched: an id and a name, and nothing else. What a search lists, so the user
can tell which of several similar titles is theirs. Someone else's data, never stored — the id is
TMDB's and only ever the thing the next question is asked with, and the Library holds what the
user copied rather than a link back to someone else's record (ADR-0002). A Series Match is to a
Tracked Series what a Watch Provider is to a Streaming Service: what a search offers, not a thing
the user owns.
_Avoid_: search result, TMDB series, candidate

**Series Details**:
What the user reads about the one series they opened from a search: its name, its original name,
what it is about, and every season TMDB lists with its episode count — season 0, the specials,
among them, because the BFF translates TMDB's shape and leaves the app's product decisions to
the app. This is what a Series Match's id is asked the next question with, and the only question
there is to ask with it. Someone else's data like the Series Match it was opened from, never
stored: it is read, and what reaches the Library is what the user copied out of it by hand
(ADR-0002).
_Avoid_: series info, TMDB record, metadata
