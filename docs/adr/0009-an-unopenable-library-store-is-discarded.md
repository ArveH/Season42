# A Library store the app can't open is discarded, not migrated

Opening the on-device store is done twice: once ordinarily, and, if that throws, once more after
deleting the store file and everything SQLite and SwiftData keep beside it under its name — the
write-ahead log, the shared-memory and journal files, the support directory. The second open finds
nothing of the old store left, so it is the same open a fresh install does. The app has no
migration plan, no versioned schema, and no code that knows two shapes of a model at once.

This is a trade of the user's Library against launching at all, and it is only defensible while
there is no Library worth keeping. There isn't: nothing has shipped, and the only stores that exist
are on development devices. **The day there is data on a device that matters, this decision has to
be taken again** — and taken as one of the alternatives below, before the schema next changes.

The immediate reason is #34. A store written by the schema of ADR-0006 cannot be opened by *any*
later schema: `TrackedSeries` and `TrackedMovie` each carried two properties with the renaming
identifier `streamingService` — the vestigial `legacyStreamingServiceName` and the relationship
beside it — and CoreData refuses to infer a mapping for an entity with a duplicate one. The
duplicate is baked into the model the store carries, so removing the properties from the code does
not rescue a store already written. That removal happens here too — the sweep ADR-0006 planned has
nothing left to adopt on a store the app will only ever open empty — but it is the recovery, not the
removal, that makes the next schema change safe.

## Considered Options

- **A versioned `SchemaMigrationPlan`.** Rejected for now: against #34's store it is unproven, and
  the thing that would have to be shown first is that SwiftData prefers a declared source model over
  the poisoned one the store reconstructs. That is the option to reach for when there is data worth
  the investigation, and this decision is what buys the time to do it properly.
- **A hand-rolled export/import: read everything through the old model, write a fresh store with
  the new one.** Rejected for now: it preserves the data, which is the whole point of it, but it is
  one-shot code that has to know both shapes and be right the first time, written for stores that
  hold nothing.
- **Leave the `fatalError` and delete-and-reinstall by hand.** Rejected: it is the same outcome as
  this decision — an empty Library — reached by way of a crash on launch and a manual reinstall.
  Where the outcome is identical, the app should not make the user perform it.
- **Fall back to an in-memory Library and keep the store on disk.** Rejected: the app would look
  like it opened and then lose everything the user did in that session, silently, on the next
  launch. A store that cannot be opened cannot be written to either, and pretending otherwise is
  worse than starting clean.
- **Move the unopenable store aside instead of deleting it.** Rejected: nothing reads it. A file
  kept for a recovery tool that does not exist is a file that quietly grows a second copy of the
  store every schema change.

## Consequences

Recovery lives in the one private function every container of the Library goes through, so it
covers the app's store and the stores tests open at an explicit URL alike, and is skipped for an
in-memory store, where there is no file to discard and a failure is a real failure. It is testable
without a schema change: a file that is not a store at all fails to open the same way a poisoned one
does — and one of those tests puts it in a directory with a space in its name, because the app's
own store lives in `Application Support` and a directory read that percent-encodes the path finds
nothing there to delete. The store from #34 itself is not something a test can write — it needs the models as they
were — so that one is checked by hand, by opening a store written by the previous release's schema.

Where a fresh store cannot be written either, the failure carries both errors. The second one only
says that writing failed; the first is the one that says why the store had to go, and losing it
would lose the only thing worth reading in a crash report.

An open that fails for a passing reason now costs the Library rather than surfacing, because the
recovery cannot tell a schema it can never open from a store it merely could not open this time. A
device out of disk is one such reason; the one to weigh hardest is file protection — a store first
opened before the device has been unlocked since boot fails to open, and would be deleted. Nothing
in the app launches before a user unlock today: there is no widget, no extension, no background
launch, and the only opener is `Season42App`. An app that grows one has to narrow this catch first,
and that is part of what the reconsideration above has to weigh.

`Season42App` keeps its `fatalError`, now reachable only when a fresh store cannot be created in an
empty directory. There is nothing to degrade to at that point.

The two `legacyStreamingServiceName` properties and `adoptLegacyStreamingServiceNames` are gone,
which retires the last part of ADR-0006 that was waiting on a day to be deleted.
