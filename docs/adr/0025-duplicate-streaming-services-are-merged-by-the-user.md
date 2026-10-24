# Duplicate Streaming Services are merged by the user, never automatically

**Status: accepted.** Follows from [ADR-0022](0022-the-library-syncs-through-the-users-icloud.md);
amends [ADR-0006](0006-streaming-services-are-registered-and-referenced.md)'s promise that no two
services share a name.

ADR-0006 keeps names unique case-insensitively, but `Library` can only check the services on
this device, and only when the user adds or renames one. When a device that already has its own
Streaming Services joins iCloud, the other device's services come in beside them, and a Library
can end up with two "Netflix". CloudKit forbids a unique constraint (ADR-0022), so nothing in
the store stops it.

Those duplicates are kept as they arrive. Fixing them is a merge the user does: the sheet that
renames a service, opened from the Streaming Services tab, offers **Merge into…** any other
service. In one save, every Tracked Series and Tracked Movie on the merged service moves to the
target, the target takes the merged service's stored Logo if it has none of its own, and the
merged service is deleted. The target keeps its name. There is no undo; a confirmation that
names the target and counts the entries that will move is the safeguard, as it is for delete.

## Considered Options

- **Merge services of the same name automatically, on sync or at launch.** Rejected: every
  device would have to pick the same survivor, or two devices would each delete the other's and
  fight. Nothing on `StreamingService` lets them agree. It has no synced creation date or ID to
  order by, and entry counts and Logos differ while a sync is half done, so a rule based on them
  picks differently depending on when it runs. Adding a field to order by is an add-only schema
  change (ADR-0022) to settle something the user can settle in two taps.
- **Offer the merge when a rename clashes with another service's name.** Rejected: it turns an
  error into a second way to merge. A rename keeps refusing with "already exists", and the Merge
  button is the one way to merge.
- **Offer only services with a similar name as targets.** Rejected: "TV 2 Play" and "TV2 Play"
  are not the same name under ADR-0006's rule, but are the same service. Which two are one is
  the user's call, so every other service is offered.

## Consequences

- `Library.mergeStreamingService(_:into:)` sits beside rename and delete, because it spans
  services and entries in one transaction, as delete does (ADR-0006). It looks both services up
  by persistent ID (ADR-0024). Merging a service into itself does nothing, and so does a merge
  when either service has been deleted on another device.
- A merge works only on what is stored: a name typed or a Logo adopted in the sheet but not
  saved is dropped, as Cancel would drop it.
- An entry set to the merged service on another device before the merge syncs there ends up
  with no service, by ADR-0006's delete rule. Last writer wins, as ADR-0022 accepts.
- The merge is offered only from the Streaming Services tab, not from the service picker inside
  an entry form.
