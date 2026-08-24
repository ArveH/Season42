# Season42

An iPhone app for tracking which series and movies one person watches across streaming services. User data lives on the device; a small API serves shared catalog data.

## Language

**Catalog**:
The shared, read-only pool of series, movies, and streaming services served by the API. Identical for every installation; never contains personal data.
_Avoid_: system data, common data

**Catalog Series / Catalog Movie**:
A template entry in the Catalog. Tracking one copies it into the user's data; the copy is thereafter independent.

**Tracked Series**:
A series the user has added to their own data — hand-entered or copied from the Catalog — including seasons, episode counts, and their watch position.
_Avoid_: show, subscription, my series

**Tracked Movie**:
A movie in the user's data. Carries only a watched/unwatched state (a watchlist entry is simply an unwatched Tracked Movie).

**Position**:
The season and episode of a Tracked Series the user has most recently watched.
_Avoid_: progress, bookmark

**Next Episode Date**:
A user-entered, optional date on a Tracked Series recording when the next episode becomes available. Not derived from the Catalog.

**Streaming Service**:
A label on a Tracked Series or Tracked Movie recording where the user watches it. Says nothing about global availability.
_Avoid_: channel, platform, provider

**Sync**:
Replacing the device's cached Catalog with the API's current contents. Never touches Tracked Series or Tracked Movies.
_Avoid_: refresh, import
