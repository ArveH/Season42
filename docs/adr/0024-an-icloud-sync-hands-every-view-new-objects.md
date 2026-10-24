# An iCloud sync hands every view new objects

**Status: accepted.** Follows from [ADR-0022](0022-the-library-syncs-through-the-users-icloud.md);
amends how [ADR-0018](0018-a-number-a-view-draws-is-counted-off-the-librarys-listings.md) counts.

When iCloud brings in a change, the Library starts a fresh `ModelContext` and re-takes its
listings from it, so every view is handed new model objects and draws again. The Library's own
writes keep the context they have: they go through the models' setters, and views are already
told about them.

**A merged change cannot say it happened.** Since #148 the Library re-reads on
`NSPersistentStoreRemoteChange`, and the values it reads back are fresh. But the fetch hands back
the very objects the rows already hold, and a change CloudKit merged in did not go through their
setters, so Observation tells no row. SwiftUI sees the same object, skips the row, and the change
shows only after a relaunch: series drew without their Streaming Service logos until then (#149).
It is ADR-0018's bug again, from a different side: a view will not be redrawn for something it
reads through a source that cannot say when it changed. A new object is a change every view
notices, including views not written yet.

The swap happens on every remote-change notification, without asking which store or which writer
posted it. If the Library's own saves turn out to post one too, the cost is a fetch and a redraw,
and rows keep their place because they are keyed by persistent ID. It is filtered only if that
cost is ever visible.

## Considered Options

- **A sync counter the Library bumps and row views read.** Rejected for the same reason ADR-0018
  rejected a token beside the count: it is a second signal bolted beside data that cannot say
  when it changed, and the next view to forget to read it is stale with no warning.
- **Rows take a copy of their values rather than the model.** SwiftUI would compare the copies
  and redraw the rows that differ. Rejected: every row is reworked, and a new view that takes a
  model is silently stale again. It is the counter's trap, spread over more code.

## Consequences

- **The Library looks up what it is handed by persistent ID.** A sheet or dialog opened before a
  sync holds an object from the old context, so every method finds the entry or service by ID in
  the current one. `entryCount(of:)` compares IDs rather than `===`.
- **A sync under an open sheet is settled as follows**, for Tracked Series and Tracked Movies alike:
  - The same entry changed on another device: the sheet keeps what the user typed, and Save
    rewrites the entry whole. Last writer wins, as ADR-0022 already says of conflicts.
  - The entry or Streaming Service deleted on another device: Save, Delete or Rename does nothing
    and the sheet or dialog closes. Its row has already gone from the listing behind it.
  - The Streaming Service picked in an add or edit sheet deleted on another device: the entry is
    saved without one, as [ADR-0006](0006-streaming-services-are-registered-and-referenced.md)'s
    nullify rule would leave it, and once the sheet closes the user is told, e.g. "Netflix was
    deleted on another device, so Severance was saved without a Streaming Service."
- The Watching tab's held-still order ([ADR-0014](0014-the-watching-order-is-the-users-and-held-still.md))
  is unaffected: its snapshot is persistent IDs, resolved against the Library's listings each time.
- Testing it needs no CloudKit. A second Library on the same store stands in for the other device,
  and the remote-change notification is posted by hand; `ObservationProbe` reads a field the way a
  row does and asks whether the row is told. Only a relationship arriving in a later import than
  its entry is left to the simulator.
