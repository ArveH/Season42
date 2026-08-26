# The seasons flatten drops, fills, and tells

Copying a Series Details into the form turns TMDB's list of seasons into the app's `Seasons`, which
is one episode count per season, numbered from 1, with no holes in it. TMDB's list has holes,
carries a season 0 for the specials, and lists seasons that have been announced but not aired. The
flatten is three rules and a fallback:

- **Drop season 0.** The app numbers seasons from 1 and has nowhere to put the specials.
- **Drop any season with no episodes.** There is nothing in it to watch, and the form cannot hold a
  season of none.
- **Fill whatever gap that leaves with the episode count of the next season that survived**, so the
  seasons the user ends up with are numbered exactly as TMDB numbers them. A gap before the first
  surviving season is filled on the same argument: a series whose season 1 TMDB does not list would
  otherwise have its season 2 renumbered to 1, which is the very thing this avoids.
- Where nothing survives, produce a single season of one episode — the least a Tracked Series can
  be.

The third rule is the whole decision. The alternative is to renumber: take what survived and lay it
out from 1. Renumbering is honest about what it knows — it invents no episode counts at all — and
it is wrong here, because it silently turns TMDB's season 4 into the app's season 3. Position is the
app's reason to exist: the user's "I am at S4E2" is written in the numbers everyone else uses, and
an app that quietly renumbers seasons underneath it has broken the one thing it was for. Filling
keeps the numbering and pays for it in invented episode counts, which are a thing the user can see
and correct in the form. Renumbering keeps the counts and pays for it in a Position that is off by a
season, which the user cannot see at all.

Because filling invents, **every invention is stated on the detail screen before Copy is tapped**:
which specials were dropped, which seasons were dropped for having no episodes, which seasons were
filled and whose count they borrowed, that no aired seasons were listed at all, and any Position the
copied seasons would move. That statement is the only thing that earns the invention. A flatten that
did the same work quietly would be the app making up the user's data for them.

## Considered Options

- **Renumber the surviving seasons from 1.** Rejected, above: it trades a visible, correctable
  episode count for an invisible, uncorrectable Position.
- **Copy TMDB's seasons as they are, specials and empty seasons included.** Rejected: `Seasons` is
  numbered from 1 and every season in it has episodes, and loosening that would push season 0 and
  zero-episode seasons through Position arithmetic, the Watching tab and the form's steppers. The
  app's shape is the app's decision, which is exactly why the BFF passes TMDB's shape through
  untouched.
- **Fill gaps with a fixed guess — one episode, or ten.** Rejected: the borrowed count is a better
  guess than a constant (a series' seasons are usually about as long as each other), and a borrowed
  count is a sentence the user can check — "10 episodes, borrowed from Season 4" — where a constant
  is only a number that appeared.
- **Refuse to copy a series with gaps and ask the user to enter it by hand.** Rejected: gaps are
  ordinary in TMDB's data, and a Copy that works only on tidy series is a Copy the user cannot
  trust to be there.
- **Copy quietly and let the user notice.** Rejected: this is the one place in the feature where the
  app invents data, and it only earns that by saying so every time.

## Consequences

The flatten is a value, not a view: `SeriesDetails.copy(over:)` produces a `SeriesCopy` — the Title,
the Description, the flattened `Seasons`, and the notes owed about them — and the detail screen
renders it and decides nothing. Every rule above is a test against that value, and the wording of
each note lives on the note rather than in the screen, because the words are the promise this
decision makes.

The notes include a Position that copying would move, which is not something the flatten does: the
form clamps the Position to the seasons it holds, as it already does while the user edits seasons by
hand. The copy predicts that clamp so that the move is stated before it happens rather than noticed
after — and the form restates it once it has, under the Position, because the screen that warned of
it is gone by then.

A copy writes the Title, the Description and the seasons, and nothing else. Status, Position,
Streaming Service, Next Episode Date and the watched state are untouched, because nothing in TMDB's
answer speaks to any of them. Copying over a form the user has already typed a Title, a Description
or seasons other than the placeholder into asks first — the whole of the seasons are compared, not
merely how many there are, because a corrected episode count is the user's own typing too; copying into a fresh form just happens. Either
way nothing is saved: Cancel abandons a copied form as completely as a typed one.
