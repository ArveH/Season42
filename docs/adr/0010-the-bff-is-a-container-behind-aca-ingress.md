# The BFF is a container behind ACA ingress, and the store it was told to throw away is mounted

The BFF becomes an image: a multi-stage build on the .NET SDK, published onto the chiseled ASP.NET
runtime, listening on plain HTTP on `:8080`. It is deployed to Azure Container Apps, and everything
the app or a person addresses is `https://`.

**TLS terminates at the ACA edge.** Container Apps holds the managed certificate for the generated
`*.azurecontainerapps.io` hostname, and hands the container plain HTTP over the environment's
internal network. So the image carries no certificate, no `ASPNETCORE_HTTPS_PORTS`, no
`UseHttpsRedirection`, and no HSTS — in something described as HTTPS-only, which is surprising
enough that it is written down here rather than left for a reader to work out from an absence.
Reading the Dockerfile alone, the honest conclusion is that TLS was forgotten. It was not: it is
one hop away, held by the platform, and the container that spoke it would be terminating a
connection that has already been terminated.

The image ships no shell. Chiseled is the runtime tag here because a server with three endpoints
has no business carrying a package manager and a `/bin/sh`, and because it runs as a non-root user
without being told to. What that costs is `docker exec` into a running container: there is nothing
in there to exec. Debugging is logs and endpoints.

**`/health` is a liveness probe and says nothing about the snapshot.** It answers `200` once the
host has started, and it is deliberately not a readiness gate. Under ADR-0007 the snapshot is
fetched at startup and refreshed daily, and a replica that has never reached TMDB still answers
searches honestly with `503`. With max one replica, marking that replica unready would take a
degraded service — one telling the app precisely what is wrong — and make it a dead one, replacing
an honest `503` from `/providers` with an ACA edge that has nowhere to send the request at all. The
probe's question is "is this process alive", not "is this process useful".

**The Logo Store gets an Azure Files mount, and that contradicts ADR-0008.** ADR-0008 says the
store holds nothing the user owns and that deleting it costs fetches — which is exactly the
argument for *not* giving it durable storage. It is being made durable anyway, and the reason is
scale-to-zero: with one replica that stops when nobody is searching, a container-local store is
emptied on a schedule no one chose, and every cold start re-fetches from TMDB whatever the last
session happened to look up. A search sheet asks for twenty logos at once. ADR-0008's point stands
undamaged — the mount holds a cache, losing it is still only fetches, and nothing in it needs
backing up or migrating. What changes is how often "only fetches" is paid.

The store path stays configurable through `Tmdb:LogoStorePath` and nothing in the image pins it:
the default remains `store` relative to the content root, and a local `docker run` starts with an
empty store and fills it. The mount is the deployment's business, not the image's.

## Considered Options

- **End-to-end TLS: a certificate in the container too.** Rejected: ACA can be told to talk HTTPS
  to the container, and it buys encryption of a hop inside a managed environment's private network.
  The cost is a certificate to obtain, mount, rotate and have expire on a Sunday, in an image whose
  whole argument for chiseled is that it carries as little as possible. A hop inside the
  environment is not the threat the app's HTTPS was protecting against; the internet between the
  phone and the edge is, and that hop is encrypted.
- **Keep `UseHttpsRedirection` in the app.** Rejected, and worse than useless: the app would see
  every forwarded request arrive as HTTP and redirect a caller who is already on HTTPS, unless it
  is also taught to trust the edge's forwarded headers. That is configuration whose only purpose is
  to undo configuration.
- **The full `aspnet:10.0` runtime image rather than chiseled.** Rejected: it exists so that a
  shell is available to debug with, and the debugging it enables is on a production container where
  that shell is also the most useful thing an intruder could find. The logs go to the platform
  either way.
- **Self-contained or AOT publish onto a runtime-deps or scratch base.** Rejected for now: it is a
  smaller image and a faster cold start, at the cost of a build that is materially harder to reason
  about for a server whose startup is dominated by an awaited TMDB fetch. The framework-dependent
  publish is the boring one, and this is not where the cold start goes.
- **A readiness probe reporting snapshot state.** Rejected: see above. It is the option that looks
  more correct and behaves worse, and it would also mean a TMDB outage during a cold start could
  keep the replica out of rotation permanently.
- **`/health` reporting the snapshot in its body, without gating on it.** Rejected here as a matter
  of not shipping two things at once: a probe endpoint whose body is read by nothing is a body that
  will drift. If an operator ever needs snapshot age, that is its own endpoint with its own
  decision, not a field smuggled into liveness.
- **No mount: let the store be container-local and re-fetch on every cold start.** Rejected: it is
  ADR-0008 applied literally, and it holds right up against scaling to zero. See above.
- **More than one replica, sharing the mounted store.** Rejected: it makes the store a shared
  writer, and ADR-0008's guarantee that TMDB is asked at most once per logo currently rests on a
  single process. One replica removes the question rather than answering it.

## Consequences

The container has no TLS story of its own, so anything that puts it somewhere other than behind an
ACA-style terminating ingress has to supply one. That includes a plain `docker run` on a public
host, which would be publishing cleartext. Locally it is loopback and fine.

`docker exec` into the running container gets nothing — there is no shell. The chiseled tag is also
why the image cannot `RUN` anything in its final stage: everything that must exist at runtime has
to be produced in the build stage or by the app itself.

Two `/health` behaviours are now load-bearing and tested: it is `200` once the host is up, and it
stays `200` when no snapshot has ever been taken while `/providers` answers `503`. A future change
that makes the probe reflect readiness will break those tests, which is the point of them.

The mounted store means a deployed BFF's disk outlives its replicas, so ADR-0008's "delete it and
it refills" becomes an operational action rather than a restart. It also means the size of the
share is now a thing that exists — a few kilobytes per logo, over the providers of one region, so
the smallest share Azure Files sells is orders of magnitude more than it needs.

The token cannot come from user-secrets in a container. Locally that makes it
`-e Tmdb__AccessToken=...`; deployed it is an ACA secret populated from a GitHub secret. The
startup message a missing token produces still names user-secrets, which is the right advice for
the place it is most often read and the wrong one inside a container; `bff/README.md` covers the
gap rather than the message growing a paragraph about deployment.
