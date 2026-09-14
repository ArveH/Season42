# Season42 BFF

An ASP.NET Core server whose only job is to hold the TMDB access token off the phone. It fetches
the configured region's TV watch providers from TMDB on startup and every 24 hours, keeps the last
good snapshot in memory and on disk, and serves matches from it (ADR-0007). It also searches TMDB
for series and for movies and reads one of either's details, which it keeps nothing of, and serves
either's poster, which it keeps. What it keeps, it keeps for `Tmdb:ImageLifetimeDays` — a day by
default, capped at the six months TMDB's terms allow: the logo and poster stores are swept on
startup and every 24 hours, and neither serves an image that has aged past the limit (ADR-0020).

Projects: `Season42.Bff` (the server) and `Season42.Bff.Tests` (xUnit, driving the real endpoints
through `WebApplicationFactory`). The solution file is `Season42.slnx` at the repo root.

## Configuration

`appsettings.json` ships the defaults, with an empty token:

| Setting | Default | What it is |
| --- | --- | --- |
| `Tmdb:AccessToken` | *(empty)* | A TMDB API Read Access Token. Empty is a startup failure. |
| `Tmdb:WatchRegion` | `NO` | The country whose TV watch providers are fetched. |
| `Tmdb:LogoStorePath` | `store` | Everything fetched from TMDB — the snapshot (`watch-providers.json`), the logo bytes (`logos/`) and the poster bytes (`posters/series/` and `posters/movies/`). Relative to the content root. |
| `Tmdb:ImageLifetimeDays` | `1` | How long a fetched logo or poster is kept before it is dropped and fetched again. Raise it as traffic makes the saved fetches worth more; anything above 170 is clamped to 170, which leaves the daily sweep room inside what TMDB's terms allow, and 0 keeps nothing (ADR-0020). |
| `RateLimit:PermitsPerWindow` | `60` | How many requests one caller may make per window. See [The rate limit](#the-rate-limit). |
| `RateLimit:WindowSeconds` | `60` | How long a window lasts. |

The token never belongs in `appsettings.json`. Set it with user-secrets:

```sh
cd bff/Season42.Bff
dotnet user-secrets set "Tmdb:AccessToken" "<your TMDB API Read Access Token>"
```

Get the token from <https://www.themoviedb.org/settings/api> — the **API Read Access Token**, not
the older API key. It is sent as an `Authorization: Bearer` header, never as a query parameter.
The BFF calls TMDB's **v3** API; the read access token is what authenticates those calls.

## The rate limit

Every route that can reach TMDB is behind a fixed-window limit of **60 requests per minute per
caller**, and a caller over it gets `429` with a `Retry-After` (ADR-0017). `/health` is not behind
it, because a `429` to Fly's probe is a machine Fly restarts.

This exists because the address below is public and the token behind it is not. The token itself is
safe either way — holding it off the phone is what this server is for (ADR-0007) — so what the limit
protects is TMDB's per-token allowance and the Fly bill, not a secret. 60 a minute is far above what
the app does (a search, a details call and a poster is three) and far below what a loop wants.

A caller is `Fly-Client-IP`, the header fly-proxy puts the real client's address in — unspoofable,
because the proxy overwrites whatever a caller sent — falling back to the connection's own address
where there is no proxy. **Many callers at once are many buckets**, which ADR-0017 says plainly is
not defended against, and why a global cap was not taken.

The limit is per-process, so the count is per machine. One more entry on the list `fly.toml` says to
read before `fly scale count` goes above 1.

## Run

```sh
cd bff/Season42.Bff
dotnet run                     # http://localhost:5265
```

Without a token it stops immediately, saying which setting is missing.

### As a container

`bff/Dockerfile` builds the server on the .NET SDK image and publishes it onto the chiseled ASP.NET
runtime, which ships no shell and runs as a non-root user. Build from `bff/`, where the build
context is:

```sh
cd bff
docker build -t season42-bff .
docker run --rm -p 8080:8080 -e Tmdb__AccessToken="<your TMDB API Read Access Token>" season42-bff
```

**The token has to be an environment variable here.** User-secrets are a file in the developer's
home directory and there is none inside the container, so a container started without
`-e Tmdb__AccessToken=...` stops at startup with the same message as anywhere else — which names
user-secrets, and is advice that does not apply where you are reading it. Any setting can be
overridden this way: `Tmdb:WatchRegion` becomes `-e Tmdb__WatchRegion=SE`, the colon written as a
double underscore.

The container listens on plain HTTP on `:8080` and holds no certificate. That is deliberate: TLS
terminates at the fly-proxy edge, which hands the container plain HTTP (ADR-0010 for why, ADR-0015
for where). A `docker run` on a public host would be publishing cleartext.

It starts with an empty store and fills it — the container mounts nothing, so the snapshot, the
logos and the posters live inside it and go when it goes. Durable storage arrives with the
deployment.

There is no shell in the image, so `docker exec` gets you nothing — and neither does
`fly ssh console` against the deployed one, for the same reason. `docker logs`, `fly logs` and the
endpoints are the way in.

## Test

```sh
dotnet test Season42.slnx      # from the repo root
```

No test reaches the network: the TMDB HTTP handler is faked at the composition root.

## One-time Fly setup

Five commands, run once. There is deliberately **no setup script** for this, in bash or anything
else: the Azure wizard this replaced earned its length by walking an Entra directory-permissions
minefield where two stages could fail on rights rather than on anything being wrong, and none of
that exists here (ADR-0015).

**Only some of these are safe to re-run.** `fly apps create` refuses if the app exists, and both
`fly secrets set` and `gh secret set` overwrite, which is what you want. **`fly volumes create` is
the exception: it does not refuse a name it already has, it creates a second volume** — and a
second volume on a single-machine app is a machine that may come back attached to an empty store.
Run `fly volumes list` before it, and leave the confirmation prompt in place rather than passing
`--yes`.

```sh
fly apps create season42-bff --org personal

# The Logo Store, the Poster Store and the snapshot. Mounted at /store, which is what
# Tmdb__LogoStorePath in bff/fly.toml points at. Check `fly volumes list` first — running this
# twice makes two volumes rather than refusing.
fly volumes create store --app season42-bff --region arn --size 1

# Set once, not per deploy: setting a Fly secret restarts the app, and this changes about
# once a year. The colon in Tmdb:AccessToken is written as a double underscore.
fly secrets set Tmdb__AccessToken="<your TMDB API Read Access Token>" --app season42-bff

# CI's credential. Scoped to this one app and able to do nothing else in the organisation.
gh secret set FLY_API_TOKEN --body "$(fly tokens create deploy --app season42-bff --name github-actions)"

# The first deploy, which creates the machine. Every one after this is CI's.
cd bff && fly deploy
```

**Check the volume is mounted, because nothing else will.** `fly volumes list` shows it attached,
but the stronger check is `fly machine status <id> --display-config`, which prints the machine's
resolved `mounts` and `env` together: the mount's path and `Tmdb__LogoStorePath` must be the same
`/store`. A volume attached at a path the server is not writing to looks exactly like a working
deployment from outside. This is the one thing about the deployment that no
test covers: an unmounted store simply re-fetches on the next cold start, silently, and there is no
shell in the image to look with. What that failure costs is fetches (ADR-0008), which is why it is
accepted rather than engineered around (ADR-0015).

| Where | Name | What it is |
| --- | --- | --- |
| GitHub secret | `FLY_API_TOKEN` | The app-scoped deploy token CI authenticates with |
| Fly secret | `Tmdb__AccessToken` | Reaches the container as an environment variable |

**There is one long-lived credential**, and there did not use to be: Fly offers no GitHub OIDC
federation for deploys, so the federated credential the Azure deployment used has no counterpart.
The trade is recorded in ADR-0015. Rotating it is `fly tokens create deploy` and updating the one
repository secret. A pull request cannot read it and does not try.

## The deployment

`bff/fly.toml` is the whole of it — there is no separate substrate to provision and nothing owns
anything the app does not. What it says, and why:

- **One machine, `shared-cpu-1x` with 512 MB.** Not Fly's 256 MB default: the .NET host wants the
  headroom, and an out-of-memory kill on an image with no shell is a bad place to debug from.
- **One machine is load-bearing, not a cost decision**, and nothing in `fly.toml` enforces it
  because Fly has no key for it — the count is however many machines exist. The snapshot is
  rewritten wholesale every 24 hours by every machine independently, so the second one exercises a
  path that never has been. `fly.toml` says so where someone about to run `fly scale count` will
  read it.
- **A 1 GB volume mounted at `/store`**, with `Tmdb__LogoStorePath` pointing at it, so fetched
  logos, posters and the snapshot survive the machine stopping. It is a local filesystem rather
  than the SMB share this replaced, so a write into place really is an atomic rename now. It pins
  the machine to a physical host and is not replicated; what is in it is a cache (ADR-0008).
- **`force_https` with the container on plain HTTP on 8080.** TLS terminates at the fly-proxy edge
  and the container holds no certificate (ADR-0010 for why, ADR-0015 for where). The Dockerfile
  already sets `ASPNETCORE_HTTP_PORTS` to 8080, which is Fly's default internal port, so `fly.toml`
  restates it rather than choosing it.
- **`auto_stop_machines = "off"` with `min_machines_running = 1`.** The machine stays up rather
  than stopping when nobody is searching. Scale-to-zero was the arrangement at first, but the cold
  start here is not just a container boot: the Watch Provider refresh is a hosted service whose
  first TMDB fetch is awaited before the app answers anything, so waking on demand put a
  multi-second wait in front of a user who had already typed. The trade is one shared-CPU machine
  billed around the clock instead of only while somebody is searching.
- **`/health` is an HTTP check with a 30-second grace period**, and that number is not the one the
  Container App's probe used. The Watch Provider refresh is a hosted service, so its first fetch
  from TMDB is awaited before `/health` answers anything, bounded at 15 seconds in `Program.cs`.
  The old 10-second initial delay would fail every cold start. It is liveness only; nothing is
  wired as readiness, for the reason ADR-0010 gives.

**Deploys are not zero-downtime**, and that is a property rather than an oversight: one machine
holding one volume cannot hand over to a second machine, because the volume cannot attach twice. It
is a few seconds, once per deploy, on an app with one user.

### The deployed address

```
https://season42-bff.fly.dev
```

That is the app's own Fly hostname and it is the app's for as long as the app exists — committed as
the default base URL in `app/Config/Bff.xcconfig`, which the build hands to the app through its
`Info.plist`. If it ever changes, this section and `Bff.xcconfig` are the two places that name it.

**The first request after an idle period can be slow.** Nothing is running, so that request waits
for a machine to start *and* for the TMDB fetch that start awaits. fly-proxy holds the connection
while the machine boots rather than refusing it, so what this costs is a wait. The next request is
served normally. That is the cost of scaling to zero, and a search is the only thing it is charged
against.

```sh
curl 'https://season42-bff.fly.dev/providers?query=net'
```

## CI

`.github/workflows/bff.yml` is the only workflow in this repository, and it is the BFF's alone.
Nothing in it builds or tests the iOS app: that needs a macOS runner and the code-signing setup,
which is a separate fight and not one worth blocking a deployment on.

| Trigger | What it does |
| --- | --- |
| Pull request | `dotnet test Season42.slnx`, and nothing else. Reaches no Fly |
| Push to `main` | The same tests, gating build → push → deploy. A red test never reaches Fly |
| `workflow_dispatch` | The same as a push, for a manual redeploy of `main` |

The push trigger is path-filtered to `bff/**`, `Season42.slnx` and `.github/**`, so a commit
touching only `app/` deploys nothing. `fly.toml` lives under `bff/`, so the deployment config needs
no filter entry of its own. Pull requests are not filtered — the tests take seconds, and a filter
there only buys the chance of merging something untested.

It reads one secret, `FLY_API_TOKEN`, and no variables at all. The app name is the workflow's own
`season42-bff`, which is also the image repository and the hostname.

**The image is built and pushed here rather than by `flyctl deploy` building it**, so that the tag
is the commit SHA. That tag is what does the work: every release points at an image traceable to a
commit, so the release list means something and a rollback is deploying an older tag. `latest` is
convenience; nothing depends on it. The deploy step then passes `--image`, which skips building
entirely.

**The TMDB token is not passed at deploy time.** It is a Fly secret set once by hand, because
setting one restarts the app and it changes about once a year — so it is out of CI's blast radius
altogether (ADR-0015).

A run ends by asking the deployed BFF for `/providers?query=net` over HTTPS. That request is given
ten tries at fifteen-second spacing, because the first request after a deploy is waiting on the
new machine booting and its awaited first TMDB fetch. A run is
green when the address in [The deployed address](#the-deployed-address) has answered with real
Watch Providers. **This is the only thing that proves the deployment**, and it proves a great deal
of it at once: the image built and pushed, the machine booted, the token present, TLS at the edge,
the snapshot fetched. What it does not prove is the volume — see the setup section above.

## The app talking to it

`BffClient` in the iOS app is the only thing that calls these endpoints, and by default it calls
[the deployed address](#the-deployed-address) over HTTPS. Nothing tells it that in Swift: the
address is the `BFFBaseURL` key of the app's `Info.plist`, substituted from `BFF_BASE_URL` in
`app/Config/Bff.xcconfig` — the same shape `DEVELOPMENT_TEAM` uses, and overridable the same way.

### Pointing a build at a BFF on your own machine

Put the override in `app/Config/Local.xcconfig`, which is gitignored:

```
BFF_BASE_URL = http:$(SLASH)$(SLASH)localhost:5265
```

`$(SLASH)` is not decoration: an xcconfig treats `//` as the start of a comment wherever it
appears, so a scheme cannot be written literally. `SLASH` is defined in `Bff.xcconfig`.

`http://localhost:5265` is the address `dotnet run` prints, which a simulator on the same machine
reaches as its own loopback.

**App Transport Security does not block this override.** The deployed default needs no help — it is
a real certificate on a real domain — so loopback is the only cleartext left, and ATS lets a request
to `localhost` from the simulator through as it is; this project carries no exception and needs
none. Should that ever change, the fix is `NSAllowsLocalNetworking` in the app's `Info.plist`, which
permits loopback and link-local addresses only; `NSAllowsArbitraryLoads` would turn cleartext on for
every host the app ever talks to and is not the answer.

**A device is not covered by any of this.** It does not share the machine's loopback, so it needs
the LAN address — which is cleartext to a host that is not loopback, and ATS refuses it. That is
the third case ADR-0010 says does not exist, and it does not exist because nothing has needed it:
searching from a device works against the deployed BFF like everything else. Wanting one anyway
means `NSAllowsLocalNetworking`, and that is a decision to take deliberately rather than a line to
add here.

Nothing the app adopts depends on the server afterwards: the logo bytes are stored on the device
(ADR-0007), so a search is the only thing a stopped BFF costs.

## The endpoints

### `GET /health`

`200` once the host has started, with nothing in the body. The one route outside the rate limit
(ADR-0017). It is a liveness probe — the deployment wires it as one — and it deliberately says
nothing about whether a snapshot has been taken: a replica that has never reached TMDB still
answers searches honestly with `503`, and calling it unhealthy would turn a degraded service into
a dead one (ADR-0010).

### `GET /providers?query=<text>`

Watch Providers whose names contain the text, case-insensitively, ordered as TMDB would order
them and capped at 20.

```sh
curl 'http://localhost:5265/providers?query=net'
[{"name":"Netflix","logoPath":"/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg"}]
```

The logo path is TMDB's own, leading slash included; it is a path into TMDB's image CDN, not a URL
this server serves.

| Situation | Answer |
| --- | --- |
| A blank or missing `query` | `400` |
| Nothing matched | `200` with `[]` |
| No snapshot has ever been taken | `503` |
| The caller is over the rate limit | `429` |

### `GET /logos/{file}`

The logo image itself, `{file}` being a `logoPath` from `/providers` without its leading slash.

```sh
curl -o netflix.jpg 'http://localhost:5265/logos/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg'
```

The first ask for a logo fetches it from TMDB's image host at size `w154` — the size that stays
sharp where rows draw logos at 16–24pt — and writes it into `logos/` under the store path. Every
ask after that is served from there, restarts included: between one fetch of a logo and the next,
TMDB is asked at most once for it. The store needs no invalidation — a logo TMDB has published does
not change under its own path (ADR-0008) — but it keeps nothing past `Tmdb:ImageLifetimeDays`, a
day by default, so an aged logo is dropped and the next ask fetches it again (ADR-0020).

The current snapshot is the allowlist. A `{file}` no Watch Provider in it names is refused before
anything touches the filesystem, which is what keeps this route from being a way to read arbitrary
files off the server; path traversal is refused by that same check rather than by a rule of its
own.

| Situation | Answer |
| --- | --- |
| The snapshot does not name the logo (traversal attempts included) | `404` |
| No snapshot has ever been taken | `503` |
| TMDB could not serve the logo | `502` |
| The caller is over the rate limit | `429` |

### `GET /series?query=<text>`

Series TMDB matched the text, in TMDB's own relevance order, each with the id to ask the next
question with and the name to show.

```sh
curl 'http://localhost:5265/series?query=severance'
[{"id":95396,"name":"Severance"}]
```

Nothing is kept and nothing is consulted: unlike `/providers`, which answers from a snapshot taken
hours ago, this asks TMDB on every request. A search is one cheap call, and what a user searches
for is often what they only just heard of — so a stale answer here would be visible to them as the
series they came for not being listed. Which is also why there is no `503`: that status means "no
snapshot has been taken yet", and this route has no snapshot to have taken.

The id is TMDB's, and it is what a later ask for one match's details is made with. It is never
stored: the Library holds what the user copied, not a link back to someone else's record
(ADR-0002).

| Situation | Answer |
| --- | --- |
| A blank or missing `query` | `400`, with no TMDB call made |
| Nothing matched | `200` with `[]` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |

### `GET /series/{id}`

Everything the detail screen shows about the one series a match was opened to: the names, the
overview, whether there is a poster to ask for, and every season TMDB lists with its episode
count — season 0, the specials, among them.

```sh
curl 'http://localhost:5265/series/95396'
{"name":"Severance","originalName":"Severance","overview":"Mark leads…","hasPoster":true,
 "seasons":[{"seasonNumber":0,"episodeCount":3},{"seasonNumber":1,"episodeCount":9}]}
```

Nothing is kept here either: a series that has just gained a season is exactly the one a user is
likely to be looking at. `hasPoster` is a yes or a no, never TMDB's poster path — the poster is
asked for by this same id (ADR-0012), and the id itself is not answered back, because the app
already has it from the match it opened.

| Situation | Answer |
| --- | --- |
| The id is not a number | `404`, with no TMDB call made |
| TMDB knows no series with that id | `404` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |

### `GET /series/{id}/poster`

The poster image of one series, at size `w342` — one size, committed to beside the logo's `w154`,
so what the user looks at is what they keep.

```sh
curl -o severance.jpg 'http://localhost:5265/series/95396/poster'
```

The first ask costs two TMDB calls — the details that say where the poster is, then the image
itself — and writes the bytes into `posters/series/` under the store path, named after the
**series id**. Every ask after that is served from there with no TMDB call at all, restarts
included, until the file has aged past `Tmdb:ImageLifetimeDays` and is evicted on the same terms
as a logo (ADR-0020). The `series/` in the path is the other half of the key: TMDB numbers its series and its
movies apart, so a movie's poster of the same id is a different file (ADR-0012). Posters written
flat at `posters/{id}.jpg` by an earlier version are simply no longer read: they are a cache, and
what they cost is one refetch each.

The id is the key on purpose, and it is what separates this store from the logo store beside it:
there is no snapshot of posters to resolve an id against, so keying on TMDB's path would mean
buying the key back with a details call on every hit. It is also what makes this route safe
without an allowlist — a poster is asked for by id and never by a path, so nothing a caller sends
becomes part of a filesystem path (ADR-0012).

Nothing is remembered about a series TMDB has no poster for. The saving that would have bought is
already in `hasPoster` on the details above, which lets the app draw its placeholder without
asking at all.

| Situation | Answer |
| --- | --- |
| The id is not a number | `404`, with no TMDB call made |
| TMDB knows no series with that id, or lists no poster for it | `404` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |

### `GET /movies?query=<text>`

Movies TMDB matched the text, in TMDB's own relevance order, each with the id to ask the next
question with and the title to show. The series search above, for the other kind of Library Entry,
and everything said there holds here: nothing is kept, nothing is consulted, and there is no `503`
because there is no snapshot to have taken.

```sh
curl 'http://localhost:5265/movies?query=arrival'
[{"id":329865,"title":"Arrival"}]
```

| Situation | Answer |
| --- | --- |
| A blank or missing `query` | `400`, with no TMDB call made |
| Nothing matched | `200` with `[]` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |

### `GET /movies/{id}`

Everything the detail screen shows about the one movie a match was opened to: the titles, the
overview, and whether there is a poster to ask for.

```sh
curl 'http://localhost:5265/movies/329865'
{"title":"Arrival","originalTitle":"Arrival","overview":"Taking place after…","hasPoster":true}
```

There are no seasons, which is the whole of what separates this from the series details above: a
movie is one thing to watch, so there is nothing for the app to flatten and nothing for it to own
up to having invented. Nothing is kept here either, and the id is not answered back, because the
app already has it from the match it opened.

`hasPoster` is a yes or a no, never TMDB's poster path — the poster is asked for by this same id
(ADR-0012) — and it is what lets the app draw a placeholder without firing an ask it expects to be
refused.

| Situation | Answer |
| --- | --- |
| The id is not a number | `404`, with no TMDB call made |
| TMDB knows no movie with that id | `404` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |

### `GET /movies/{id}/poster`

The poster image of one movie, at size `w342`, on the same terms as the series poster above and
out of the same store: a miss pays the details call that says where the poster is and then the
image, every ask after that is served from disk, and nothing is remembered about a movie TMDB
lists no poster for.

```sh
curl -o arrival.jpg 'http://localhost:5265/movies/329865/poster'
```

The bytes land in `posters/movies/` under the store path, named after the **movie id**. The two
keyspaces are TMDB's own, so a series and a movie that share a number keep separate posters.

| Situation | Answer |
| --- | --- |
| The id is not a number | `404`, with no TMDB call made |
| TMDB knows no movie with that id, or lists no poster for it | `404` |
| TMDB refused, said nothing, or answered with something unreadable | `502` |
| The caller is over the rate limit | `429` |
