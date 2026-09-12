# A number a view draws is counted off the Library's listings

How many Library Entries name a Streaming Service is answered by `Library.entryCount(of:)`,
which counts the entries in the Library's own `trackedSeries` and `trackedMovies`. The two
inverse relationships on `StreamingService` stay exactly as
[ADR-0006](0006-streaming-services-are-registered-and-referenced.md) put them, because the
nullify delete rule is written in terms of them — but nothing draws a number from them any more.

**The inverse holds the right number and cannot say when it changed.** Naming a service is
written on the entry: `series.streamingService = netflix`. SwiftData keeps `netflix.series` in
step, and a test that reads it straight afterwards gets the right count — but a SwiftUI body
that read it is never told, so it is not redrawn. The Streaming Services tab went on saying
`0 entries` for a service with entries until the app was relaunched, and its delete confirmation
took the quiet branch and said "This can't be undone." about a service whose entries were about
to be left naming none (#106).

The Library's listings are the other side of the same store and are told about: `Library` is
`@Observable` and re-takes all three listings on every write, so a body that read a count through
one of them is a body SwiftUI knows to run again.

**Asking the Library is the whole of it; where in the view the row asks is not.** The tab reads
the count inside its row builder, which is where it always read it. That was tried both ways in
the simulator — the count taken in `body` and handed to the row, and the row asking for it itself
— and both redraw. `streamingServices` is re-taken on every write like the other two listings, so
the rows are rebuilt whatever else changed, and a row rebuilt asks for a fresh count. Only the
source of the number was ever wrong.

## Considered Options

- **Leave the count on `StreamingService` and make the tab refresh some other way** — a `@Query`
  in the tab, or a token the Library bumps that the view reads beside the count. Rejected: both
  keep a number whose source cannot say when it changed and bolt a second, parallel signal beside
  it. The next view to read `entryCount` gets the stale one and no warning, which is how this bug
  was written the first time.
- **Have the Library refresh the services after every write, so the inverse is re-faulted.**
  Rejected: it is what the Library already does — `reload()` re-takes all three listings on every
  write — and the tab was stale anyway. Re-assigning `streamingServices` reports a change to the
  list, and the row it rebuilds then reads a count from a place that has not caught up.
- **Store the count on the service and maintain it on every write.** Rejected: a denormalised
  count is a second thing to keep true, and the entries are already the truth. ADR-0005 made the
  Library the only store; a count it can derive is not worth storing twice.
- **Keep `entryCount` on the model but hand it the Library to count from.** Rejected: it is the
  Library's listings doing all the work behind a method on something else — the count belongs
  where the data it counts lives.
- **Take the counts in `body` and hand each row a number it cannot get wrong.** Rejected as
  guarding against nothing: both shapes were driven in the simulator and both redraw, so the
  structure would be an invariant no test could hold and a reader could not check.

## Consequences

ADR-0006's Consequences said the inverses "are what make the entry count on the tab cheap". That
sentence is amended there: the inverses are for the delete rule, and the count is the Library's.
The relationships themselves are unchanged, and so is everything ADR-0006 decided about what
deleting a service does.

The count is a scan of both listings per service, so drawing the tab is a scan per service on the
screen. For a handful of registered services and the number of entries one person tracks, that is
well below anything worth caching — and the listings are in memory already, where the relationship
it replaces could be a fault to fill.

A test that asserts the count is a number cannot catch this class of bug — every such test passed
while the tab was wrong. Testing it means reading the count under `withObservationTracking` and
asking whether the read was reported as changed, which is what `ObservationProbe` in the tests is
for. Only the entry being *added* makes that a real question: a Library write re-takes every
listing, so a probe on almost any other change is told whatever the count is read from. The count
tests beside it are still worth having, but they are tests of a number and would not have caught
this.

This is a rule about counts a view draws, not only about this one. Anything a view reads back
through the far side of a relationship is a number the view will not be redrawn for.
