# Catalog entries are templates, not linked records

When the user starts tracking a Catalog Series or Catalog Movie, the app copies it into their data; the copy is thereafter independent, and Sync only ever replaces the cached Catalog — it never touches user data.

## Considered Options

- Two separate pools with duplicates coexisting — rejected: makes the Catalog pointless as a starting point.
- Tracked entries *link* to Catalog entries so syncs update underlying series data — rejected for now: drags in merge semantics (what if the user edited their copy?) that a single-user v1 doesn't need. Revisit if/when the Catalog gets a real data source (TMDB-like) with per-episode air dates.

## Consequences

A new season announced in the Catalog does not appear on an existing Tracked Series; the user updates their copy by hand. Catalog DTOs carry an external id and poster URL field so a future real data source can slot in without reshaping the app.
