# A Release Slot says the week and sorts by the day

A Tracked Series can now carry a Release Slot beside its Next Episode Date: a weekday and a time
of day, entered together, for a series whose episodes turn up week after week. The two coexist —
the form holds both and neither clears the other — and every row that lists the series says the
Slot where there is one and the date otherwise.

**The row says the recurrence, not the next occurrence.** "Tuesdays at 21:00" is what the user
typed and what the row says, forever. The alternative was to work out the coming Tuesday and draw
`Tue 16 Sep, 21:00`, which reads more precisely and is worse: it is a claim about now, it goes
stale under a listing the user is looking at, and it needs a rule for whether 21:00 today has
happened yet. The Next Episode Date line already promises never to judge a date — one that has
gone by is still what the row says — and a Slot drawn beside it keeps the same promise.

**The Waiting listing ranks by the coming occurrence all the same.** That listing exists to answer
"what is back next", soonest first. Ranking a Slot as dateless would bury a series that airs
tomorrow beneath one that airs in March, which is the listing failing at its one job for exactly
the series this feature is for. So the order compares the next occurrence of the Slot against the
dates around it, and the row still says the recurrence. Words and rank are allowed to disagree
because they answer different questions: the row says what the user knows, the order says what is
soonest.

**An occurrence rolls over at local midnight, not at the Slot's time.** The Waiting listing is
computed live on every draw, unlike the held-still Watching listing above it, so a rank that
turned over at 21:00 would move a row down the screen while the user was reading it — a small
version of the defect ADR-0014 exists to fix. Rolling over at midnight means "it airs today" holds
all day, which is true, and the order only ever changes while nobody is watching.

**A day is a tie.** A Next Episode Date carries no time of day, so a Slot's 21:00 is compared
against a precision the user never entered. Same-day is a tie, broken as it always was, by most
recently added first.

**Day and time go in together.** A weekday with no time is weak information and a time with no
weekday is none at all; a user who knows only the day can leave the Slot off and put the date in.
One toggle, two pickers, two states instead of four, and one line of words to render.

**It is wall-clock local.** No time zone is stored — a weekday and minutes past midnight, not a
`Date`. This is the user's own note about when to look, not a broadcast schedule, and it should
read the same after they fly somewhere else.

## Considered Options

- **A separate optional weekday and optional time.** Rejected: it buys a "Tuesdays, some time"
  state nobody asked for and a "at 21:00, some day" state that means nothing, and it doubles the
  display cases for the shared line.
- **Draw the computed next occurrence on the row.** Rejected above: it makes the row a judgement
  about now, in a line whose whole character is that it never judges.
- **Sort a Slot-only series as dateless, at the foot of Waiting.** Rejected: simplest to write and
  it breaks the listing's promise for the series the Slot is for.
- **Roll the occurrence over at the Slot's own time.** Rejected: the Waiting listing is live, so
  the row would move under the user at 21:00. Midnight is the quiet hour.
- **Compare a Slot's occurrence against a date down to the minute.** Rejected: the date has no
  minute in it. Inventing one to sort by would make the order depend on a value the user never
  gave.
- **Anchor the Slot to the device's time zone at entry and translate it afterwards.** Rejected: it
  buys correctness for a fact the app does not have — the user typed when *they* see episodes, not
  when a broadcaster publishes them — and costs the user a row that quietly says something other
  than what they entered.
- **Clear the Next Episode Date when a Release Slot is set,** since rows no longer draw it.
  Rejected: silently discarding a value the user typed because they typed another one is expensive
  the first time it happens and cheap to avoid. The form shows both; only the row chooses.
- **Let a Copy fill the Slot from TMDB's air dates.** Rejected: the BFF's Series Details does not
  carry them, and the Slot joins Status, Position, Streaming Service and Next Episode Date as
  something a Copy never touches (ADR-0002). Nothing invented means no Copy Note.

## Consequences

The Waiting listing's order can no longer be read off the rows. Two series can sit one above the
other with the upper one saying "Tuesdays at 21:00" and the lower one saying a date in October,
and the reason the upper is upper is a computation the screen never shows. This is the price of
the rank being useful, and it is paid only in the one listing that is ordered by when a series is
back.

The order now depends on the clock, so the Waiting listing is no longer a pure function of the
Library. Anything testing it has to say what "now" is, the way the Watched At stamp already does.

`Next Episode Date` and `Release Slot` will both be drawn by the one shared line, so the choice
between them is made once, in one place, for all four rows that list a Tracked Series — the
Library's series row, and the Watching tab's Watching, Waiting and Lapsed rows.

The weekday word is a localizable string per day rather than a formatted weekday with an `s`
appended, because the plural is a fact about English and not about dates. The app is English-only
today; this keeps the plural rule out of the code that builds the line.
