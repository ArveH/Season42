# A BFF fetches provider logos; the app keeps the bytes

A second deployable comes back. `bff/` holds an ASP.NET Core server that reads a TMDB v4 Read
Access Token from configuration, fetches a region's TV watch providers from TMDB, and answers
"which streaming services does TMDB know of whose name looks like this?". The token stays on the
machine the server runs on. The app never holds it and never talks to TMDB.

This reverses the "keep the API as a proxy in front of TMDB" option that ADR-0005 rejected, using
the escape hatch ADR-0005 itself wrote: *"Revisit if a TMDB key must never reach a device the user
controls."* That is exactly the case here — TMDB requires an access token on every request, and
anything shipped in an iPhone binary can be extracted from it.

What makes the reversal acceptable rather than merely necessary is the second half of the
decision: **a logo the user adopts is stored on the device as image bytes.** The app needs the BFF
only while searching. Every logo already adopted keeps drawing with the BFF stopped, unreachable,
or never deployed. ADR-0005's objection to a second deployable — "a second thing to be down" — is
answered not by arguing the server will stay up, but by making its being down cost nothing except
the ability to search for a new one.

The BFF keeps only what a search needs: a Watch Provider's name, TMDB's logo path, and TMDB's
display priority for the configured region. TMDB's per-country priority map is discarded on the
way in. A snapshot is taken on startup and every 24 hours, held in memory and written to disk; a
refresh that fails logs and leaves the previous snapshot standing, and a restart reads the file
back rather than waiting on TMDB. A search before any snapshot exists is a `503`, not an empty
array — "I do not know yet" and "nothing matched" are different answers and the app will show them
differently.

## Considered Options

- **Ship the TMDB token in the app binary and drop the server.** Rejected: it is not a secret once
  it is on a device the user controls — strings in an app bundle are extractable, and a leaked
  token is revoked against every user of it at once. This is the constraint that forced a server;
  no amount of obfuscation turns a shipped string into a held one.
- **Store the logo path on the Streaming Service and re-fetch the image on every render.** Rejected:
  it makes the BFF a runtime dependency of the Watching and Library tabs, which are the two screens
  that must work on a train. A path is smaller than bytes, and the saving is a few kilobytes per
  registered service against an app that cannot draw its own rows offline.
- **Keep TMDB's provider id so an adopted logo could be refreshed later.** Rejected: it is ADR-0002's
  rejected "link to Catalog entries" option in new clothing, and the live question ADR-0005 left
  open. A service's logo changes on the order of a rebrand; the escape when it does is the same one
  the user already has for a wrong logo — search again and adopt the new one. Holding the id would
  buy an automatic refresh nobody asked for, and would put a TMDB identifier into the Library,
  which is the user's own by ADR-0005.
- **Have the BFF store the user's Streaming Services too, now that a server exists.** Rejected: the
  Library is the only store (ADR-0005), and the reason the BFF can be a localhost toy is that
  nothing the user owns is in it. A server holding user data is a server that must be backed up,
  migrated and reachable.

## Consequences

The repo is two deployables again, and `Season42.slnx` returns to the root. The BFF is
single-purpose and stateless as far as the user is concerned: everything in it is a cache of
someone else's data, and deleting its store directory costs a fetch.

A missing token is a startup failure with a message naming the setting, rather than a server that
starts, looks healthy, and answers every search with the same unexplained emptiness. The token is
sent as an `Authorization: Bearer` header, never as a query parameter, so it stays out of access
logs and proxy caches.

The BFF's tests drive the real endpoints through `WebApplicationFactory` with the TMDB HTTP handler
faked at the composition root. Nothing in the test suite reaches the network, so TMDB being down,
rate-limiting, or changing its data is never a red build.

Serving the logo bytes themselves is a second endpoint filling the same store the snapshot sits in,
and is deliberately not part of this decision.
