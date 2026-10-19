# A Library store the app can't open is kept and migrated, never discarded

**Status: accepted.** Supersedes
[ADR-0009](0009-an-unopenable-library-store-is-discarded.md), which said of itself: "the day there
is data on a device that matters, this decision has to be taken again". That day has come — the
user's Library is real — and the iCloud schema change of
[ADR-0022](0022-the-library-syncs-through-the-users-icloud.md) is the next schema change.

Nothing the app does deletes a Library store any more. The schema is versioned: today's models are
V1, the iCloud-ready models V2, and the move between them is an explicit migration in a
`SchemaMigrationPlan`. A store that still won't open is moved aside, kept, and the failure is said
to the user, rather than being deleted. The store is never opened while protected data is
unavailable — before the first unlock since boot — because that failure is passing, not a broken
schema, and treating it as one is how a background launch would lose a Library.

Before the migration reaches the user's phone it is run against a copy of their real store, taken
off the device, and the user exports the Library to a file from Settings beforehand as a net that
does not depend on the migration being right.

## Considered Options

- **Keep discarding, now that iCloud would refill the store.** Rejected: the store is discarded
  exactly when the schema changes, which is before the data has ever reached iCloud. The first
  failure would be the one that costs everything.
- **The hand-rolled export/import ADR-0009 rejected.** Kept, but as the user's backup (Library
  Export) rather than as the migration: it is a net under the migration, not a replacement for
  one.

## Consequences

A store moved aside is not read by anything automatically; with iCloud on, the fresh store fills
from the cloud, and the kept file is there for a hand recovery if it doesn't. Each later schema
version is a new entry in the migration plan and, under ADR-0022, an addition rather than a
rename. The tests that opened a garbage file to prove the discard now prove it is kept instead.
