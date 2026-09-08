# The Watching order is the user's, and held still

The Watching tab used to list one way — most recently watched first — recomputed from the data on
every draw. Marking an episode watched therefore moved that series to the top under the user's
finger, and the next tap landed on a different series than the one they had aimed at. The order is
now one of two the user picks between, Watched At or Title, and whichever they pick is taken as a
snapshot and held still until they ask for another one.

**Two orders, because "most recently watched" answers only half the question.** It is the right
order for working down what you are mid-way through, and the wrong one for finding a particular
series among twenty. Title order is the other half. They are offered as a segmented control above
the listing rather than hidden in a menu, so which one is on is readable without tapping anything,
and the choice is remembered between launches — it is a preference, not a mode entered and left.

**Held still, because a list that reorders under a tap is a list that cannot be tapped twice.**
The snapshot is re-taken when the user picks an order, and when they arrive on the tab from
another tab. Nothing else re-takes it: not marking watched, not taking a watch back, not editing a
series, and — this is the deliberate part — not returning from a sheet opened over the tab. A
sheet is not leaving the tab. Editing the third row down and coming back to find the list
rearranged is a smaller version of the same complaint, and the fix would not be a fix if it left
that case in.

**Taking a watch back now stamps Watched At, because the freeze is what made the old rule
unnecessary.** The stamp used to survive an un-watch, and the reason was written into the code: a
mistap should not move a series down the list. Under a held-still order nothing moves down the
list, so the rule was protecting against something that can no longer happen — and it was buying
that protection with an inaccuracy, leaving a series stamped with a watch the user had taken back.
Both directions stamp now, which changes what the stamp means: not "when did I last see an
episode" but "when did I last move through this series". The Watching Order is ordering progress,
and that is the honest field to order it by.

**A Status change leaves the row where it is, dimmed.** Answering Finished or Waiting from a row
does not remove it — it lapses it: the row dims, says its new Status where the Position was, and
offers Edit alone. This is the freeze applied to membership as well as order, and it is what makes
a mis-tapped Finished cheap: the user fixes it on the row they mis-tapped, in the form they
already have a button for, and the row un-lapses in place. Sweeping it out of the listing would
send them to the Library tab to hunt for a series they had just been looking at.

**Deletion is the one thing the freeze does not hold.** The snapshot is a list of ids re-resolved
against the Library on every draw, so a series deleted while the tab is frozen drops out at once
and everything else keeps its place. Position is what is frozen; existence never is. A row for a
series that no longer exists has nothing to undo and nothing to draw.

**The Waiting listing is untouched.** It stays ordered by soonest Next Episode Date, which answers
a different question — what is back next — and which Title order would destroy. The two buttons
govern the Watching listing and say nothing about the one below it.

## Considered Options

- **Keep one order and simply stop it recomputing.** Rejected: it fixes the tap problem and leaves
  the user with no way to find a series by name in a long list. The complaint that started this
  was about tapping; the second order is what makes the tab usable for the other thing people do
  with it.
- **Make the order a live sort — pick "Last watched" and have the list re-sort as stamps change.**
  Rejected: that is the current behaviour with a label on it. The series would still jump under
  the finger whenever that order was selected, which is the entire defect.
- **Re-take the snapshot on every appearance of the tab, sheets included.** Rejected as above: the
  edit button added to each row makes sheet-return a common path, not a rare one.
- **Restore Watched At to its previous value on an un-watch** rather than stamping the moment of
  the un-watch. Rejected: the app keeps no history to restore from, and would have to start
  keeping one to serve a case the user hits rarely. Stamping now is one line and is true to what
  the field has come to mean.
- **Change a Tracked Movie's `watchedAt` to match.** Rejected: nothing orders by it, and it
  answers a genuinely different question — when the film was watched, a fact about the film. The
  two fields stopped being one idea here, and the glossary says so rather than pretending
  otherwise.
- **Sweep a Finished or Waiting row out of the listing immediately.** Rejected on the user's own
  reasoning: the tap that lapses a row is exactly the tap most likely to be a mistake, and the
  cheapest place to undo it is the row it happened on.
- **Strip a leading "The" when ordering by Title.** Rejected: it is a per-language rabbit hole,
  and it surprises the user by filing a series somewhere other than where they typed it. Titles
  order by `localizedStandardCompare`, so case and diacritics behave as a reader expects and "The
  Bear" files under T.

## Consequences

The Watching listing can now disagree with the Library about what is in it, for as long as the
user stays on the tab. That is the point, and the dimming is what keeps the disagreement honest:
a Lapsed Row never claims to still be Watching, and never offers a next episode to mark.

The freeze cuts the other way too. A series set to Watching from a Waiting row leaves the
Waiting listing at once — that listing is live — and is not in the snapshot, so left alone it
would vanish from the tab, and an only series would leave the tab showing its empty state over a
Library that holds a Watching series. It is appended below the snapshot instead, drawn as any
Watching row, several joiners in the order in force. Nothing above it moves, which is all the
freeze asks. It is not adopted into the snapshot: that would be a write on read, and the row set
back to Waiting simply returns to the Waiting listing on the same screen, where the mis-tap is
undone. The next re-take sorts it in.

`lastWatchedAt` no longer means what its name says, and the glossary carries the discrepancy
rather than the code being renamed around it. Anything that comes to want "when did the user last
see an episode" — a history, a streak, a stat — will have to record that separately, because this
field has stopped answering it.

The chosen order lives outside the Library, in the app's preferences. It is not a Library Entry
and the store that holds the user's own things (ADR-0005) is not where a preference about a
listing belongs. The Appearance choice lands in the same place for the same reason.

## Addendum, 2026-09-08: a pull re-takes the snapshot too

"Nothing else re-takes it" left the user with no way to ask for a fresh listing on the tab
itself: a listing full of Lapsed Rows could only be swept by picking the other order or by a
detour through another tab. Pulling the listing down now re-takes the snapshot, the third moment
beside picking an order and arriving, and the only one the user asks for outright. It is the
gesture every iPhone list has taught them means "sort this out now", which is exactly what a
deliberate re-take is, and it changes nothing about the freeze: rows still hold still under a
tap, a sheet closing is still not an arrival, and the search text and the Waiting listing are
untouched by it. There is nothing to fetch, so the platform's spinner shows for as long as the
instant re-take takes and no longer.
