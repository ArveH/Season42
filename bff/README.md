# Season42 BFF

An ASP.NET Core server whose only job is to hold the TMDB access token off the phone. It fetches
the configured region's TV watch providers from TMDB on startup and every 24 hours, keeps the last
good snapshot in memory and on disk, and serves matches from it (ADR-0007). It also searches TMDB
for series and reads one series' details, which it keeps nothing of, and serves that series'
poster, which it keeps.

Projects: `Season42.Bff` (the server) and `Season42.Bff.Tests` (xUnit, driving the real endpoints
through `WebApplicationFactory`). The solution file is `Season42.slnx` at the repo root.

## Configuration

`appsettings.json` ships the defaults, with an empty token:

| Setting | Default | What it is |
| --- | --- | --- |
| `Tmdb:AccessToken` | *(empty)* | A TMDB API Read Access Token. Empty is a startup failure. |
| `Tmdb:WatchRegion` | `NO` | The country whose TV watch providers are fetched. |
| `Tmdb:LogoStorePath` | `store` | Everything fetched from TMDB — the snapshot (`watch-providers.json`), the logo bytes (`logos/`) and the poster bytes (`posters/`). Relative to the content root. |

The token never belongs in `appsettings.json`. Set it with user-secrets:

```sh
cd bff/Season42.Bff
dotnet user-secrets set "Tmdb:AccessToken" "<your TMDB API Read Access Token>"
```

Get the token from <https://www.themoviedb.org/settings/api> — the **API Read Access Token**, not
the older API key. It is sent as an `Authorization: Bearer` header, never as a query parameter.
The BFF calls TMDB's **v3** API; the read access token is what authenticates those calls.

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
terminates at the Container Apps edge, which hands the container plain HTTP on the internal network
(ADR-0010). A `docker run` on a public host would be publishing cleartext.

It starts with an empty Logo Store and fills it — the container mounts nothing, so the store lives
inside it and goes when it goes. Durable storage arrives with the deployment.

There is no shell in the image, so `docker exec` gets you nothing. `docker logs` and the endpoints
are the way in.

## Test

```sh
dotnet test Season42.slnx      # from the repo root
```

No test reaches the network: the TMDB HTTP handler is faked at the composition root.

## One-time Azure setup

Before anything can be deployed, a subscription needs a resource group and a Container Apps
environment to deploy *into*, and CI needs an identity to deploy *with*. Those are provisioned
once and are not owned by the deployment template — re-running a template that owns the substrate
it deploys onto is a much riskier operation than re-running one that does not.

```sh
./scripts/azure-setup.sh
```

An interactive wizard, safe to re-run: every stage checks for what it is about to create and
leaves it alone if it is already there. It walks eight stages — confirming the subscription,
registering the Azure resource providers, creating the resource group and the Container Apps
environment, capturing the TMDB access token, registering an Entra identity with a federated
credential scoped to this repository's `main` branch, granting that identity its two roles on the
resource group, and handing the values to GitHub.

The two roles are Contributor, which covers the deployment, and Role Based Access Control
Administrator, which exists only because the template hands the container app's identity AcrPull
on the registry — a role assignment, which Contributor may not write. It is granted under a
condition allowing AcrPull and nothing else, so CI cannot use it to widen its own access.

It captures nothing you have to edit into it beforehand, and it stores no credential in the repo:
values land in `.env` (gitignored) and in GitHub Actions secrets and variables.

| Where | Name | What it is |
| --- | --- | --- |
| Secret | `AZURE_CLIENT_ID` | The Entra app registration CI authenticates as |
| Secret | `AZURE_TENANT_ID` | The directory that app lives in |
| Secret | `AZURE_SUBSCRIPTION_ID` | The subscription everything is created in |
| Secret | `TMDB_ACCESS_TOKEN` | Reaches the container as an ACA secret at deploy time |
| Variable | `AZURE_RESOURCE_GROUP` | Where the deployment template puts everything |
| Variable | `AZURE_LOCATION` | The region, `norwayeast` by default |
| Variable | `AZURE_CONTAINERAPP_ENV` | The environment the app runs in |

**No long-lived credential exists anywhere.** CI authenticates by OIDC federated credential, which
is why there is no client secret in GitHub; the deployed app pulls its image with a managed
identity, which is why there is no registry password in Azure. The federated credential is scoped
to `main`, so a pull request cannot use it — pull requests run the tests and never reach Azure.

Two stages can fail on permissions rather than on anything being wrong: registering an Entra
application, and granting a role. The wizard says so plainly when it happens and prints the exact
command for someone with the rights to run, rather than failing with a raw CLI error.

The registry, the storage account and its file share are **not** created here. They are the
deployed app's own dependencies, they change when the app changes, and the deployment template
owns them.

## The deployment

`infra/main.bicep` is everything the BFF needs in Azure that the setup above did not create: a
container registry, a storage account with a file share for the Logo Store, and the Container App
itself. It is **parameterised on the resource group and the Container Apps environment**, and owns
neither — those are the substrate, and a template that owns the ground it stands on is a much
scarier thing to re-run than one that does not.

| Parameter | Default | What it is |
| --- | --- | --- |
| `containerAppEnvironmentName` | *(required)* | The environment to deploy into — the `AZURE_CONTAINERAPP_ENV` variable |
| `tmdbAccessToken` | *(required, secure)* | Becomes the ACA secret behind `Tmdb__AccessToken` |
| `location` | the resource group's region | Where the registry, storage account and app are created. Has to be the environment's region, and the default is right whenever the environment sits in its own resource group's region — which is how `scripts/azure-setup.sh` creates it |
| `appName` | `season42-bff` | Names the Container App, its identity, and the image repository |
| `image` | the Container Apps placeholder | The image the app runs |

```sh
set -a && . ./.env && set +a          # the values scripts/azure-setup.sh wrote

az deployment group create \
  -g "$AZURE_RESOURCE_GROUP" -f infra/main.bicep \
  -p containerAppEnvironmentName="$AZURE_CONTAINERAPP_ENV" \
  -p tmdbAccessToken="$TMDB_ACCESS_TOKEN" \
  -p image="$REGISTRY_LOGIN_SERVER/season42-bff:$TAG"
```

**The `image` default is a bootstrap, not a value to leave alone.** The registry does not exist
until this template has created it, so the first deployment has nothing of ours to pull and runs
the placeholder image Container Apps ships. Every deployment after that passes the image it just
pushed — which is what the deploy workflow does — and a deployment that leaves the parameter at
its default puts the placeholder back.

The template outputs `fqdn`, `registryLoginServer`, `registryName` and `containerAppName`. The
registry and storage account names are derived from a hash of the resource group rather than asked
for, because both have to be globally unique; read them from the outputs rather than guessing.

What it creates, and why it looks the way it does:

- **The registry** has its admin user off, and no credential for it exists anywhere. The Container
  App pulls with a user-assigned managed identity holding `AcrPull` on the registry. The identity
  is user-assigned rather than system-assigned so that it exists — and holds the role — before the
  app that pulls with it is created.
- **The file share** is mounted at `/store`, and `Tmdb__LogoStorePath` points at it, so fetched
  logos and the snapshot survive a revision restart. It is the smallest share Azure Files sells,
  which is already far more than one region's logos need. Mounting Azure Files needs a storage
  account key — the one credential here with no managed-identity form — and the template reads it
  at deploy time rather than storing it anywhere.
- **Ingress is external on port 8080 with `allowInsecure: false`**. TLS terminates at the edge and
  the container is handed plain HTTP (ADR-0010). What that setting does is answer an `http://`
  request with a `301` to the `https://` address — it does not refuse the connection, and Container
  Apps offers nothing that does. So the guarantee is not "cleartext is refused" but "nothing is
  ever *served* over cleartext": the only thing that crosses an `http://` connection is a bodyless
  redirect. Turning the setting on would let plain HTTP reach the container, which is the thing
  being prevented.
- **`/health` is wired as a liveness probe** and nothing is wired as a readiness probe, for the
  reason ADR-0010 gives.
- **Scale is min 0, max 1.** Zero means a cold start pays the awaited first TMDB fetch, which is
  the accepted trade. One is load-bearing rather than a cost decision, and the Bicep says so where
  someone about to raise it will read it: the snapshot-write path assumes a single writer.

### The deployed address

```
https://season42-bff.livelyocean-b2b153fc.norwayeast.azurecontainerapps.io
```

That is the generated `*.azurecontainerapps.io` hostname, and it is the app's default base URL —
committed in `app/Config/Bff.xcconfig`, which the build hands to the app through its `Info.plist`.
The generated segment belongs to the Container Apps environment and is stable for its life; it
changes only if the environment is recreated — at which point this section and `Bff.xcconfig` are
the two places that name it.

**The first request after an idle period can time out.** Nothing is running at min 0, so that
request waits for a container to start *and* for the TMDB fetch that start awaits — long enough
that the edge has been seen to answer `504` before the container was ready. The next request is
served normally. That is the cost of scaling to zero, and a search is the only thing it is charged
against.

```sh
curl 'https://season42-bff.livelyocean-b2b153fc.norwayeast.azurecontainerapps.io/providers?query=net'
```

## CI

`.github/workflows/bff.yml` is the only workflow in this repository, and it is the BFF's alone.
Nothing in it builds or tests the iOS app: that needs a macOS runner and the code-signing setup,
which is a separate fight and not one worth blocking a deployment on.

| Trigger | What it does |
| --- | --- |
| Pull request | `dotnet test Season42.slnx`, and nothing else. Reaches no Azure |
| Push to `main` | The same tests, gating build → push → deploy. A red test never reaches Azure |
| `workflow_dispatch` | The same as a push, for a manual redeploy of `main` |

The push trigger is path-filtered to `bff/**`, `infra/**`, `Season42.slnx` and `.github/**`, so a
commit touching only `app/` deploys nothing. Pull requests are not filtered — the tests take
seconds, and a filter there only buys the chance of merging something untested.

It reads exactly what `scripts/azure-setup.sh` wrote and nothing else — the secrets
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `TMDB_ACCESS_TOKEN`, and the
variables `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` and `AZURE_CONTAINERAPP_ENV`. A fresh clone is
wired up by running that script; the table under [One-time Azure setup](#one-time-azure-setup) is
the whole list. Two names it does *not* ask for: the registry is found in the resource group,
which holds exactly one, and the app is the template's default `season42-bff`, which also names
the image repository.

**Authentication is an OIDC federated credential**, so no client secret exists in GitHub. Two
things follow, and both are load-bearing:

- The deploy job asks for `id-token: write`. Without it `azure/login` fails in a way that reads
  like a bad credential rather than a missing permission.
- The deploy job names no `environment:`. A job that names one gets an OIDC subject of
  `repo:<owner>/<repo>:environment:<name>`, and the credential is scoped to
  `ref:refs/heads/main` — so naming an environment would break the login. A credential for any
  other ref is a second federated credential, never a widening of this one.

**Images are tagged with the git SHA and with `latest`**, and it is the SHA tag that is doing the
work: every Container Apps revision points at an image traceable to a commit, so the revision list
means something and a rollback is a redeploy of an older tag. `latest` is convenience; nothing
depends on it.

**The registry has to exist before CI's first run**, because the deployment template is what
creates it and the workflow does not run that template until it has an image to pass. So the
first deployment is the hand-run under [The deployment](#the-deployment); every run after it is
CI's. A workflow that provisioned the substrate it deploys onto would be a much scarier thing
than one that finds it already there, so it refuses with that instruction rather than creating
anything. Every deploy passes the image it just pushed, because leaving that parameter at its
default puts the placeholder back.

A run ends by asking the deployed BFF for `/providers?query=net` over HTTPS. That request is
given ten tries at fifteen-second spacing, because the app scales to zero and the first request
after a deploy is waiting on a cold start and the awaited first TMDB fetch — the edge has been
seen to answer `504` before the container was ready. A run is green when the address in
[The deployed address](#the-deployed-address) has answered with real Watch Providers.

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

`200` once the host has started, with nothing in the body. It is a liveness probe — the deployment
wires it as one — and it deliberately says nothing about whether a snapshot has been taken: a
replica that has never reached TMDB still answers searches honestly with `503`, and calling it
unhealthy would turn a degraded service into a dead one (ADR-0010).

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

### `GET /logos/{file}`

The logo image itself, `{file}` being a `logoPath` from `/providers` without its leading slash.

```sh
curl -o netflix.jpg 'http://localhost:5265/logos/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg'
```

The first ask for a logo fetches it from TMDB's image host at size `w154` — the size that stays
sharp where rows draw logos at 16–24pt — and writes it into `logos/` under the store path. Every
ask after that is served from there, restarts included: TMDB is asked at most once per logo. The
store never expires and needs no invalidation, because a logo TMDB has published does not change
under its own path (ADR-0008).

The current snapshot is the allowlist. A `{file}` no Watch Provider in it names is refused before
anything touches the filesystem, which is what keeps this route from being a way to read arbitrary
files off the server; path traversal is refused by that same check rather than by a rule of its
own.

| Situation | Answer |
| --- | --- |
| The snapshot does not name the logo (traversal attempts included) | `404` |
| No snapshot has ever been taken | `503` |
| TMDB could not serve the logo | `502` |

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

### `GET /series/{id}/poster`

The poster image of one series, at size `w342` — one size, committed to beside the logo's `w154`,
so what the user looks at is what they keep.

```sh
curl -o severance.jpg 'http://localhost:5265/series/95396/poster'
```

The first ask costs two TMDB calls — the details that say where the poster is, then the image
itself — and writes the bytes into `posters/` under the store path, named after the **series
id**. Every ask after that is served from there with no TMDB call at all, restarts included.

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
