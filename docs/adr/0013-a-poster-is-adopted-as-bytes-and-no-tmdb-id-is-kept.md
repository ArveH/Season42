# A Poster is adopted as bytes, and no TMDB id is kept

A Library Entry carries its Poster as image bytes on itself, exactly as a Streaming Service
carries its Logo ([ADR-0007](0007-a-bff-fetches-provider-logos-the-app-keeps-the-bytes.md)). Copy
writes them in along with the Title, the Description and — for a series — the seasons; the form
shows the adopted Poster with a Remove button; and the id the poster was fetched with is discarded
with the rest of the details it was read from.

Taken for a Tracked Series first and extended to a Tracked Movie unchanged: the two adopt on the
same terms, and everything below is written of both.

**Bytes, because the Library and Watching tabs must draw on a train.** They are the two screens
the user reaches for most, and neither is a screen the BFF has any business being in. The app
needs the BFF only while searching, and this is what keeps that true once posters are on the
rows: a `w342` poster is a few tens of kilobytes and the Library is a personal one, so the cost
is a store that grows with what the user adopted rather than a tab that goes blank when a
container is down. It is the same argument ADR-0007 made about logos, and the answer has to be
the same one or the offline promise only half holds.

**Fetched once, on the way to the screen that draws it.** The detail screen asks for the poster
when the details say there is one, and the bytes it drew are the bytes Copy keeps. The user is
shown the picture they are about to adopt, which is the point, and adopting it costs no second
fetch — a second one could also come back with something else, since the BFF's poster store keys
on the series id and TMDB re-posters a returning series (ADR-0012).

**No TMDB identifier reaches the Library.** The id fetches the details and the poster and is then
gone, so a Tracked Series holds no link back to someone else's record —
[ADR-0002](0002-catalog-entries-are-templates.md) and
[ADR-0005](0005-the-library-is-the-only-store.md) again, and the same rejected option ADR-0007
turned down for provider ids. Re-adopting a poster means searching for the series again, which is
what the user would do anyway to find the one they meant.

**A poster that will not fetch is no poster, and nothing more.** `hasPoster` says what TMDB's
answer said, not that the image host will serve it (ADR-0012), so the fetch is allowed to fail:
the detail screen draws its placeholder, Copy still works, and the entry simply has none. A match
whose logo won't load already adopts its name on exactly these terms.

**Remove is on the form, beside the Poster, and takes only the Poster.** The escape from a wrong
copy has to be smaller than the copy was. Without it, being rid of a picture adopted by mistake
would mean discarding everything else the copy filled in — or the entry — which is the objection
that put a Remove beside the adopted Logo in the first place.

## Considered Options

- **Keep the TMDB series id on the Tracked Series and fetch the poster on every render.**
  Rejected twice over: it puts someone else's identifier into the user's own data, and it makes
  the BFF a runtime dependency of the Library and Watching tabs. That is ADR-0007's rejected
  option verbatim, and nothing about posters makes it a better trade than it was for logos — the
  bytes are larger here, and so is what is lost when they can't be fetched.
- **Fetch the poster only when Copy is tapped.** Rejected: the user would adopt a picture they
  had not seen, and the screen that asks them to choose between similar titles is exactly the
  screen a poster helps on. It saves a fetch for a match that is opened and abandoned, which is
  a fetch the BFF's store makes cheap anyway.
- **Fetch twice — once to draw, once to keep.** Rejected: two asks for one adoption, and the
  second can answer differently from the first. What the user looked at is what they should end
  up with.
- **Store the poster in SwiftData external storage rather than inline.** Rejected for now on
  ADR-0007's reasoning: it buys file management, and a personal Library of a few hundred entries
  at a few tens of kilobytes each is not the size of problem that needs it. Revisit if a Library
  grows large enough that the store's size is felt.
- **Let Copy leave an already-adopted Poster standing when the new series has none.** Rejected:
  a copy replaces the fields TMDB's answer speaks to, and leaving one series' picture over
  another series' name is the one outcome nobody would have asked for. Remove is how a Poster is
  kept when nothing replaces it.
- **Ask the user whether to take the poster, separately from the rest of the copy.** Rejected: a
  second question on a screen that already carries the Copy Notes, for a thing Remove undoes in
  one tap.

## Consequences

The Library's store grows with the pictures in it. Deleting a Tracked Series takes its Poster
with it, and there is no orphan to collect: the bytes are a field on the entry, not a file
beside it.

A Poster can go stale in the only way that matters — the user adopted the poster of the season
they were watching, and TMDB has since published another. Nothing refreshes it, deliberately.
The escape is the one the user already has for a wrong Logo: search again and copy again.

`hasPoster` is now the only thing the app reads about a poster before asking for one, so a
series TMDB advertises a poster for and then refuses is indistinguishable, on screen, from one
it never had. Both draw the placeholder, which is the honest answer either way.

Movies adopt on these terms too, and the rows that draw a Poster come after that: the shape of a
Poster was settled here so neither had to settle it again.
