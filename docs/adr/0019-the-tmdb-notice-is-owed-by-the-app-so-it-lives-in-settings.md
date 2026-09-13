# The TMDB notice is owed by the app, so it lives in Settings

TMDB's [API Terms of Use](https://www.themoviedb.org/api-terms-of-use) ask for the notice
"prominently **in or on Your Application**", and for the TMDB logo to identify the app's use of
TMDB. The [attribution page](https://www.themoviedb.org/about/logos-attribution) says "every
application that uses our data or images is required to properly attribute TMDB as the source."
Every one of those is scoped to the application. Nothing in either document asks for a credit
beside each poster, and TMDB's own products carry none.

So the app discharges it once, in one permanent place: a headerless `TmdbAttribution` section at
the foot of the Settings tab, below About. The Library tab, the Watching tab and the Streaming
Services list draw TMDB's posters and logos and carry no attribution at all, and that is not an
oversight to be corrected later — it is what the terms actually ask for.

**Settings is where "prominently" is satisfied and the sheets were not.** Before this, the
attribution was drawn only inside three modal sheets — the series search, the movie search, and
the one that names a Streaming Service. A sheet is transient and reached only while adding
something. A user who fills a Library in the first week and then only watches never sees the
notice again, and a reviewer looking for it has to guess that "+" leads to it. An app-scoped
obligation discharged only in three dismissible sheets has no permanent site in the app at all.
Settings is always reachable, needs nothing added first, and is the first place anyone looks for
what an app is built on.

**The sheets keep theirs, as redundancy rather than a second requirement.** They are where a user
watches TMDB's data arrive, and the notice costs a section. If they lost it tomorrow the app would
still be in the right; if Settings lost it, it would not.

**Because Settings is the notice that discharges the duty, it names both halves.** Series and
movie details and posters are TMDB's own; streaming service names and logos reach the app by way
of TMDB, with the streaming data JustWatch's. A sheet may credit only what it is showing. The
app's one permanent notice may not say less than the app takes, which is why `Credits.wholeApp`
exists rather than the Settings section reusing `.seriesAndMovies` or carrying a bare required
sentence.

**The mark is not a link, here or anywhere.** The terms ask for the mark's presence, not for it to
be tappable. Making it a link only in Settings would put a conditional inside a component that has
none, for nothing the terms asked for.

## Considered Options

- **Credit TMDB on every screen that draws its images** — a line under the Library listing, the
  Watching tab, the Streaming Services list. The genuine alternative, and the one the code's own
  doc comment implied by opening "What TMDB's terms ask of a screen that shows its data or its
  images". Rejected: the terms say application, not screen. Per-screen crediting means the same
  sentence maintained in five or six places, a line of legal text on every listing the user reads
  daily, and a promise the app then has to keep on every listing added afterwards — all to
  over-deliver on an obligation the app can discharge once.
- **Leave the attribution in the three sheets alone and add nothing.** Rejected on the word
  *prominently*. Not in breach on any reading we can defend, but a notice a long-time user cannot
  find and a reviewer has to hunt for is a thin answer to "prominently in or on your application",
  and the cost of removing the doubt is one section.
- **Fold the attribution into the About section's footer.** Rejected: `TmdbAttribution` is dropped
  unchanged into four places now, and giving it a second shape for this one would ripple through
  the three sheets for no gain.
- **Make the mark in Settings a link to TMDB.** Rejected above: unasked-for, and a conditional in
  a component that has none.
- **Ask TMDB where they want it (#116) and place it accordingly.** Considered and dropped. The
  position stands on the terms' own wording, and shipping does not wait on an answer. If an answer
  ever arrives reading differently, it lands here.

## Consequences

`SettingsView` grows past preferences: it now also carries About — the app's version and build off
`Bundle.main`, through `AppBuild`, and links to the published privacy and support pages — and the
attribution below it. That is the shape of the decision, not drift: Settings is the app-level tab,
and app-level notices belong on it. The version is there for the same reason, since the support
page asks people to report a problem and cannot ask them which build they are on.

`TmdbAttribution`'s doc comment points here rather than restating the argument, and no longer says
the terms ask this of a screen.

A future reader seeing uncredited posters on the Watching tab will assume an oversight and be
wrong. That is what this ADR is for.

Revisiting this after the app has been reviewed and listed on this footing is awkward — moving the
notice is cheap, but conceding that per-screen crediting was owed would mean the listed build was
not compliant. The reading above is the one to challenge if anyone wants to reopen it, not the
placement.
