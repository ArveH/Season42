# The Catalog snapshot

`catalog.json` is the Catalog: the shared, read-only pool of streaming services, series
and movies. It is served verbatim by the API's `GET /catalog` and bundled unchanged into
the iOS app as the snapshot it fills its Catalog cache from on a first launch. One file,
two consumers, so the two can't drift — see [ADR-0003](../docs/adr/0003-one-canonical-catalog-snapshot-file.md).

## Editing it

Edit this file and nothing else. The API copies it to `Data/catalog.json` in its output at
build time; the app target references it as `../catalog/catalog.json` in its Resources
build phase. Both `dotnet test` and the app's `CatalogTests` read what you leave here, so
a malformed entry fails a test rather than a launch.

Every series needs at least one season, and every season at least one episode — the app
rejects anything else. `description` is what the app calls a summary; `posterUrl` is
unused until images arrive.

## Where the data comes from

The series and movies are real entries from [The Movie Database](https://www.themoviedb.org/):
their titles, overviews, poster URLs, and per-season episode counts, with the TMDB id as
`externalId`. Streaming services carry hand-written slug ids — they are the services this
app cares about rather than a TMDB listing.

The data was taken from TMDB's pages by hand, not fetched from their API. This project is
not endorsed or certified by TMDB.
