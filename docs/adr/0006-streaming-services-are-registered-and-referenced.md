# Streaming Services are registered once and referenced, not typed onto every entry

A Streaming Service is a stored thing with a name, registered in a tab of its own. A Tracked
Series or Tracked Movie names at most one by holding a reference to it, so renaming a service
renames it everywhere it is named. The free-text field on the two forms is gone, replaced by a
picker of what the user has registered. This is the app's first reference between two stored
things — until now the Library held two kinds of entry that knew nothing of each other.

Deleting a Streaming Service leaves the entries that named it naming none. The user is told how
many first; nothing they track is deleted.

The names already typed are carried across rather than dropped. The string property on both
models is renamed `legacyStreamingServiceName`, keeping its stored name through
`@Attribute(originalName: "streamingService")`, and `Library.init` sweeps every entry still
holding one: find or register a service of that name, point the entry at it, clear the string.

## Considered Options

- **Keep it a value list: the tab manages allowed strings, entries keep copying one.** Rejected:
  editing a service in the tab would then mean nothing to the entries already on it, and the
  duplicate-spelling problem the tab exists to solve would come back the first time a name
  changed. A reference is the only version where "edit the streaming services" is a real verb.
- **Refuse to delete a service entries still name.** Rejected: it turns cancelling a
  subscription into a chore across every entry on it, in service of a consistency the app does
  not need — an entry with no service is already an ordinary, valid entry. The count in the
  confirmation is what keeps the nullify from being a surprise.
- **A `SchemaMigrationPlan` with a versioned V1→V2 stage for the migration.** Rejected: to read
  the old string at all, V2 has to carry it under a legacy name anyway, so the version plan buys
  ceremony rather than safety. A sweep in `init` is idempotent — it needs nothing remembered
  about whether it has run — and is testable through the facade the way a relaunch already is.
- **Drop the typed names and have the user re-pick.** Rejected: it silently deletes something
  they typed. ADR-0005 was willing to orphan a store no code reads; this would discard live data
  out of the store the app is still using.
- **Seed a list of the usual services on first launch.** Rejected: any such list is a guess at a
  particular viewer's subscriptions, and a wrong guess is rows to delete. The migration supplies
  exactly the services actually in use.

## Consequences

`Library` grows the service methods rather than handing them to a second facade: deleting a
service spans services and entries in one transaction, and a seam through that operation would
be a seam through its only hard part. `StreamingService` holds two inverse relationships, one
per kind of entry, because a Library Entry is a way of reading the two kinds together and not a
thing that is stored — there is no single relationship to point at. Those inverses are what make
the entry count on the tab cheap and the nullify SwiftData's job rather than hand-written.

Names are unique case-insensitively, so "netflix" and "Netflix" cannot both be registered. Where
both were already typed on entries, the sweep collapses them and keeps the spelling on the most
recently added entry.

Two vestigial `legacyStreamingServiceName` properties stay in the models, along with the sweep
that empties them, until no store can still carry one. They are dead weight the day after every
device has opened the app once, and the commit that removes them removes all three together.

Filtering the Library by Streaming Service is now one line of `LibraryFilter`, and is
deliberately not part of this change.
