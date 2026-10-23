# The Library syncs through the user's iCloud

**Status: accepted.** Amends [ADR-0005](0005-the-library-is-the-only-store.md): the Library is
still the only store, but it no longer lives on the device alone. Settles the question
[ADR-0001](0001-user-data-on-device-api-serves-catalog-only.md) deferred "until the app ever needs
a second client" — the Watch App is that client.

The Watch App marks episodes watched, takes them back and answers Finished or Waiting, and has to
work with the iPhone off or out of range. So the Library becomes a SwiftData store mirrored to the
user's private CloudKit database, and the iPhone and the Watch App each hold a full copy of it.
Nothing about the Library's shape changes for the user; where it is kept does. Where iCloud is
unavailable to the app the iPhone carries on alone exactly as before, and the Watch App says it
needs iCloud rather than showing anything.

The Watching Order goes with it, through iCloud's key-value store, so the Watch App lists in the
order the user picked on the phone. Appearance does not: a watch app is always dark.

## Considered Options

- **The iPhone's Library stays the only copy; the Watch App holds a read-only copy pushed over
  WatchConnectivity and sends its taps back as queued commands.** One source of truth, no
  add-only schema, ADR-0005 untouched. Rejected because the Watch App goes stale whenever the
  phone has been out of reach, and the user wants it to stand on its own.
- **Two local Libraries merged over WatchConnectivity.** Rejected: every cost of the chosen option
  plus conflict resolution written by hand.

## Consequences

- **The CloudKit schema is add-only once it is deployed to production.** No field is renamed,
  deleted or retyped again; a change of mind is a new field beside the old one. This is the cost
  that lasts.
- Every model has to meet CloudKit's rules: every stored property optional or defaulted, every
  relationship optional (`StreamingService.series` and `.movies` become optional arrays), no
  unique constraints. That is a schema change on a store that holds real data, so it lands only
  behind [ADR-0023](0023-an-unopenable-library-store-is-kept-and-migrated.md).
- The whole Library syncs to the watch, Tracked Movies, Posters and Logos included: one store
  cannot sync part of itself. The Watch App draws Posters and Logos, so the bytes earn their place.
- Posters and Logos move to SwiftData external storage in the same schema change, reversing what
  [ADR-0007](0007-a-bff-fetches-provider-logos-the-app-keeps-the-bytes.md) and
  [ADR-0013](0013-a-poster-is-adopted-as-bytes-and-no-tmdb-id-is-kept.md) chose for an on-device
  store: a store that now has a second copy on another device is worth keeping lean. CloudKit
  still sends them as bytes inside the record, not as separate assets (the spike, #137), so a
  record is still capped at 1 MB in total. TMDB's `w342` Posters sit far below that: the
  largest in the user's Library was 97 KB when V2 was written.
- Conflicts are last-writer-wins. The same series marked on both devices before either has synced
  advances once, not twice; that needs two devices on one series within seconds, and is put
  right by hand.
- Syncing is eventual — usually seconds, sometimes minutes — and nothing on either device says
  how fresh it is.
- Two things are proven by a spike against CloudKit's development environment before any of this
  reaches the user's Library: that the Codable values (`Seasons`, `Position`, `ReleaseSlot`,
  `WatchStatus`) sync, and that turning sync on for a store that already holds data uploads it.
- iCloud pushes can wake the app in the background, which is the launch ADR-0009 warned it had
  never had. ADR-0023 is what makes that safe.
