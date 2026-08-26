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

## Test

```sh
dotnet test Season42.slnx      # from the repo root
```

No test reaches the network: the TMDB HTTP handler is faked at the composition root.

## The endpoints

`GET /providers?search=<text>` — Watch Providers whose names contain the text, case-insensitively,
ordered as TMDB would order them and capped at 20.

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
under its own path.

The current snapshot is the allowlist. A `{file}` no Watch Provider in it names is refused before
anything touches the filesystem, which is what keeps this route from being a way to read arbitrary
files off the server; path traversal is refused by that same check rather than by a rule of its
own.

| Situation | Answer |
| --- | --- |
| The snapshot does not name the logo (traversal attempts included) | `404` |
| TMDB could not serve the logo | `502` |
