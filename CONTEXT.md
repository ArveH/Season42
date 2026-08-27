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
What a Tracked Series or Tracked Movie is about, typed by the user or copied in from a search
and theirs to edit from there. Carried in code as `summary`, because SwiftData reserves the name
`description`.
_Avoid_: synopsis, blurb, note (as a name for this text — a Copy Note is a different thing)

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

**Poster**:
The picture of a Library Entry the user adopted with a Copy, held on
the entry as bytes exactly as a Logo is held on a Streaming Service, and for the same reason: what
the app has adopted must draw with the BFF stopped, unreachable or never deployed, which the
Library and Watching tabs need of it (ADR-0013). Once adopted it is theirs: nothing
refreshes it, and no TMDB identifier is kept beside it, so re-adopting means searching again.
Theirs to be rid of, too — the form shows the adopted Poster with a Remove that takes the Poster
and nothing else with it, as the adopted Logo has. An entry may carry none, and a Poster that
would not fetch costs a picture and nothing else: everything else still copies. Where a Poster
slot is drawn and there is none to draw, the `photo` symbol in secondary grey stands in — a
different symbol from the `tv` that stands in for a missing Logo, so that where the two are drawn
together "no poster" and "no logo" never look alike. Every row that lists a Library Entry leads
with the slot — both Library rows, and the Watching tab's Watching and Waiting rows — so a column
of rows lines up whether or not there is a Poster to draw.
_Avoid_: cover, artwork, image, thumbnail

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

**Poster Store**:
Where the BFF keeps the poster images it has fetched, one file per series or movie under that
entry's id — deliberately not under the path TMDB published it at, as the Logo Store is
(ADR-0012). The id is only half the key: TMDB numbers its series and its movies apart, so the two
are kept apart in the store as well and a shared number is no collision. It fills
itself the way the Logo Store does and nothing in it expires either; what differs is the key, and
what it costs. A hit is answered without asking TMDB anything at all, and only a miss pays a
details call to find the poster and then the image itself. Nothing is remembered about a series or
a movie TMDB has no poster for. Like the stores beside it, it holds nothing the user owns: deleting it
costs fetches.
_Avoid_: poster cache, image proxy

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
what it is about, whether there is a poster to be had, and every season TMDB lists with its
episode count — season 0, the specials, among them, because the BFF translates TMDB's shape and
leaves the app's product decisions to the app. Whether there is a poster is a yes or a no and never
TMDB's path to it: the poster is asked for by the same id, which is what makes that ask safe with
no allowlist to check it against (ADR-0012). This is what a Series Match's id is asked the next
question with, and the only question there is to ask with it. Someone else's data like the Series
Match it was opened from, never stored: it is read, and what reaches the Library is what the user
copied out of it by hand (ADR-0002).
_Avoid_: series info, TMDB record, metadata

**Movie Match**:
A movie a search matched: an id and a title, and nothing else. What a search lists, so the user
can tell which of several similar titles is theirs. Someone else's data, never stored — the id is
TMDB's and only ever the thing the next question is asked with (ADR-0002). A Movie Match is to a
Tracked Movie exactly what a Series Match is to a Tracked Series; they are separate terms because
they are separate asks of the BFF, and a movie is titled where a series is named.
_Avoid_: search result, TMDB movie, candidate

**Movie Details**:
What the user reads about the one movie they opened from a search: its title, its original title,
what it is about, and whether there is a poster to be had — a yes or a no and never TMDB's path
to it, exactly as a Series Details answers it. No seasons, which is the whole of what
separates it from a Series Details: a movie is one thing to watch, so nothing about it is
flattened and nothing about a Copy of it is invented. This is what a Movie Match's id is asked the
next question with, and the only question there is to ask with it. Someone else's data like the
Movie Match it was opened from, never stored (ADR-0002).
_Avoid_: movie info, TMDB record, metadata

**Copy**:
Taking a Series Details into the form the search was opened over: its name becomes the Title, its
overview becomes the Description, its seasons become the app's, flattened to what the app can hold
(ADR-0011), and the poster the detail screen drew becomes the Poster — the very bytes the user
looked at, fetched once rather than twice (ADR-0013). Nothing else moves — Status, Position,
Streaming Service, Next Episode Date and
the watched state are the user's alone, and TMDB's answer says nothing about them. From the moment
it lands, everything copied is the user's own, as editable as if they had typed it and saved no
sooner: the Library holds what was copied, never a link back to where it came from (ADR-0002).
Because the flatten invents episode counts, every invention is stated on the detail screen before
Copy is tapped, as a Copy Note.

Copying a Movie Details is the same act with less in it: the title becomes the Title, the overview
becomes the Description, and the poster the detail screen drew becomes the Poster, on the same
terms as a series' — the very bytes the user looked at. That is all there is. No seasons to flatten
means nothing invented and so no Copy Note, and the Streaming Service and the watched state are
the user's alone as they are for a series.
_Avoid_: import, sync, add from TMDB

**Copy Note**:
One thing a Copy would do that the user could not have read off TMDB's answer: a season dropped, a
season invented and whose count it borrowed, that no aired season was listed at all, or a Position
the copied seasons would move. Every one of them is on the detail screen before Copy is tapped, and
a moved Position is said again on the form afterwards — the screen that warned of it is gone by
then. Each carries its own wording, because the words are the promise ADR-0011 makes rather than a
matter of layout.
_Avoid_: warning, caveat, disclaimer
