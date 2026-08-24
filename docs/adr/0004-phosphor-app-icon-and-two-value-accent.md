# The app icon is `S42` in phosphor green, and the accent colour has two values

The icon is the season code `S42` standing on a row of six episode blocks, four of them lit —
a season, an episode number, and a watch position in one mark — drawn in 1980s green-monitor
phosphor on a green-black ground. The blocks are segmented rather than a continuous bar
because a series advances one episode at a time: discrete blocks say "episodes" where a solid
fill says "loading". The same phosphor green is the app's accent colour, but it
cannot be one value: phosphor green is 1.4:1 against white, so `AccentColor` carries a Light
Mode value of `#0F7A32` (5.5:1 on white) and a Dark Mode value of the phosphor itself.

## Considered Options

- **A television idea** — a play glyph, a screen, an episode grid — rejected: legible but
  generic, and the App Store search grid puts this icon beside a dozen apps that already own
  that shape. `S42` says television with no pictorial content at all, because anyone who has
  read an episode number can read it.
- **A bare `42`** — rejected: distinctive, but tells a browsing stranger nothing about what
  the app does.
- **Douglas Adams iconography** — the towel, Marvin, the paperbacks' trade dress — rejected:
  it borrows someone else's identity for an app going to the App Store, and dates the icon
  to a joke rather than to the app. The reference lives in the name; the icon is just a
  numeral, and whoever gets it, gets it.
- **Amber on near-black**, the obvious warm evening-television palette — rejected: it is
  Plex's palette, and Plex is precisely the neighbour in the grid.
- **One accent value for both jobs** (a mid green around `#1B9E3F` that works on white and in
  the icon) — rejected: it costs the icon the phosphor glow, which is the whole idea. Two
  values in one asset is what appearance variants are for.

## Consequences

**Do not collapse `AccentColor` to a single value.** The two variants look like an oversight
and are not: the Dark value is unusable on white, and the Light value is dead on the icon's
ground. They are the same hue at two drive levels, which is also what the icon does with its
lit and unlit phosphor.

The icon is authored in Icon Composer as layered art, not as a flat PNG, because the
deployment target is iOS 26 and there is no older system to serve the legacy look. Two
constraints follow, and both are the reason the drawing looks the way it does:

- The tinted and clear variants render every layer as the same monochrome glass, so anything
  carried by colour alone disappears there. The lit blocks are therefore also *taller* than
  the unlit ones — the watch position survives as a step in the silhouette. The `S`/`42`
  hierarchy is colour-only and is allowed to collapse; `S42` as three equal glyphs is still
  a correct mark.
- Only the halo sits on the mid layer. The type and the blocks are one rigid object on the
  foreground, because Liquid Glass parallaxes layers independently and a mark whose halves
  slide against each other reads as broken rather than deep.

No CRT texture — no scanlines, no curvature, no painted bloom. The palette comes from the
monitor; the surface comes from Icon Composer, whose glass and specular passes already do
that job and turn to mud underneath hand-painted glow. The texture is also the first thing
to vanish at the 120px the App Store grid actually renders.
