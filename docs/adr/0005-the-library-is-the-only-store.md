# The Library is the only store; the Catalog and the API are gone

A series or a movie exists in exactly one place: the Library, on the device, entered by hand.
The shared Catalog, the ASP.NET Core API that served it, `catalog/catalog.json`, the on-device
Catalog cache and the Sync that filled it are all deleted. The tab bar is Watching and Library.
This supersedes ADR-0001, ADR-0002 and ADR-0003, which are kept on file — they are the record
of a road taken and backed out of, and their reasoning is what the TMDB work inherits.

## Considered Options

- **Keep the Catalog, point it at TMDB.** Rejected: it keeps the whole two-pool machine — a
  second SwiftData store, a browse tab, a copy-into-the-Library step, an already-tracked mark,
  a launch-time Sync — in order to mirror a catalogue that is already someone else's and is
  three orders of magnitude larger than anything worth caching. TMDB is a lookup, not a pool
  to hold.
- **Keep the API as a proxy in front of TMDB.** Rejected: it is a second deployable, a second
  place to put a key, and a second thing to be down, for a single-user app whose only client
  is the phone. Revisit if a TMDB key must never reach a device the user controls, or if a
  second client appears.
- **Keep the app's Catalog code dormant behind a flag.** Rejected: code with no caller has no
  test pressure on it and rots in place. Git remembers it; the branch that adds TMDB can read
  it there.

## Consequences

One store, one schema, one way in. `Library.track(_:)` and `Library.isTracked(_:)` are gone,
and with them the title-comparison rule that decided whether two entries named the same thing
— the app no longer has two pools to compare across. The user gains nothing to browse and
loses nothing they could do: the Library tab's "Add" menu already covered both kinds by hand.

The repo becomes app-only. Devices that ran an older build keep an orphaned Catalog store
file; nothing cleans it up, because this is pre-release and single-device.

The TMDB work that follows fills a form the user is already looking at, rather than stocking a
pool the user browses. ADR-0002's rejected "tracked entries *link* to Catalog entries" option
is the one live question it inherits: whether a Library Entry filled from TMDB keeps the TMDB
id, and so whether it can ever be refreshed. That decision is deliberately left open here.
