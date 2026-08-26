# Season42 BFF

An ASP.NET Core server whose only job is to hold the TMDB access token off the phone. It fetches
the configured region's TV watch providers from TMDB on startup and every 24 hours, keeps the last
good snapshot in memory and on disk, and serves matches from it (ADR-0007).

Projects: `Season42.Bff` (the server) and `Season42.Bff.Tests` (xUnit, driving the real endpoints
through `WebApplicationFactory`). The solution file is `Season42.slnx` at the repo root.

## Configuration

`appsettings.json` ships the defaults, with an empty token:

| Setting | Default | What it is |
| --- | --- | --- |
| `Tmdb:AccessToken` | *(empty)* | A TMDB API Read Access Token. Empty is a startup failure. |
| `Tmdb:WatchRegion` | `NO` | The country whose TV watch providers are fetched. |
| `Tmdb:LogoStorePath` | `store` | Everything fetched from TMDB — the snapshot (`watch-providers.json`) and the logo bytes (`logos/`). Relative to the content root. |

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
credential scoped to this repository's `main` branch, granting that identity Contributor on the
resource group, and handing the values to GitHub.

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

That is the generated `*.azurecontainerapps.io` hostname, and it is what the app compiles in as its
default base URL. The generated segment belongs to the Container Apps environment and is stable for
its life; it changes only if the environment is recreated.

**The first request after an idle period can time out.** Nothing is running at min 0, so that
request waits for a container to start *and* for the TMDB fetch that start awaits — long enough
that the edge has been seen to answer `504` before the container was ready. The next request is
served normally. That is the cost of scaling to zero, and a search is the only thing it is charged
against.

```sh
curl 'https://season42-bff.livelyocean-b2b153fc.norwayeast.azurecontainerapps.io/providers?search=net'
```

## The app talking to it

This describes a BFF running on the developer's machine. A deployed one is addressed over HTTPS,
and the cleartext below is the one exception ADR-0010 keeps.

`LogoApi` in the iOS app is the only thing that calls these endpoints, and
`http://localhost:5265` is its default base URL — the address `dotnet run` prints, which a
simulator on the same machine reaches as its own loopback. A device does not: point the base URL
at the machine's LAN address through `LogoApi(baseUrl:)` if you ever need one to search.

**App Transport Security does not block this.** ATS refuses cleartext HTTP in general, and this
project carries no exception, but a request to `localhost` from the simulator goes through as it
is — verified against a running server from the app target. Should that ever change, the fix is
`NSAllowsLocalNetworking` in the app's Info.plist, which permits loopback and link-local addresses
only; `NSAllowsArbitraryLoads` would turn cleartext on for every host the app ever talks to and is
not the answer.

Nothing the app adopts depends on the server afterwards: the logo bytes are stored on the device
(ADR-0007), so a search is the only thing a stopped BFF costs.

## The endpoints

### `GET /health`

`200` once the host has started, with nothing in the body. It is a liveness probe — the deployment
wires it as one — and it deliberately says nothing about whether a snapshot has been taken: a
replica that has never reached TMDB still answers searches honestly with `503`, and calling it
unhealthy would turn a degraded service into a dead one (ADR-0010).

### `GET /providers?search=<text>`

Watch Providers whose names contain the text, case-insensitively, ordered as TMDB would order
them and capped at 20.

```sh
curl 'http://localhost:5265/providers?search=net'
[{"name":"Netflix","logoPath":"/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg"}]
```

The logo path is TMDB's own, leading slash included; it is a path into TMDB's image CDN, not a URL
this server serves.

| Situation | Answer |
| --- | --- |
| A blank or missing `search` | `400` |
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
