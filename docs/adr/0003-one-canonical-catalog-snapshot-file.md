# One canonical Catalog snapshot file, referenced by both projects

**Status: superseded by [ADR-0005](0005-the-library-is-the-only-store.md).** Kept because it records a road taken and backed out of; the reasoning still bears on how TMDB data is handled.

`catalog/catalog.json` at the repo root is the Catalog. The API serves that file verbatim
from `GET /catalog`, and the iOS app bundles the same file as the snapshot it fills its
Catalog cache from on a first launch. Neither project owns a copy: the API's csproj
`Include`s it from outside the project directory, and the app's Xcode target references it
as `../catalog/catalog.json` in its Resources build phase.

## Considered Options

- A copy in each project, kept in step by hand or by a build step — rejected: the ticket
  asks for byte-identical, and two files are only ever byte-identical until someone
  forgets. A copying build step makes the drift silent rather than impossible.
- The app fetching the Catalog on first launch instead of bundling it — rejected: a first
  launch with no network has to show a populated Catalog tab, and Sync is a later ticket.

## Consequences

Editing the Catalog is one edit. Nothing has to test that the two consumers agree, because
there is nothing to disagree: both build from the same path, and a build that can't find it
fails. The app target has one file reference that lives outside its filesystem-synchronized
group, so moving or renaming `catalog/` means editing `project.pbxproj` by hand.

The snapshot's data comes from [The Movie Database](https://www.themoviedb.org/): real
titles, overviews, poster URLs, per-season episode counts, and TMDB ids as `externalId`,
so the future real data source ADR-0002 anticipates is the one the test data already
describes. Streaming services keep hand-written slug ids — they are the services this app
cares about, not a TMDB listing.
