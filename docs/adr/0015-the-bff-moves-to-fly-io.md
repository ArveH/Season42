# The BFF moves from Azure Container Apps to Fly.io

The BFF is deployed to Fly.io as the app `season42-bff` in `arn`, reachable at
`https://season42-bff.fly.dev`. It was an Azure Container App ([ADR-0010](0010-the-bff-is-a-container-behind-aca-ingress.md)),
and this supersedes that one's *hosting* decision and nothing else.

The reason is proportion. Getting a three-endpoint server serving one phone onto Container Apps
took a resource group, a Container Apps environment, a container registry, a storage account with
a file share, an Entra app registration carrying two OIDC federated credentials, an AcrPull role
assignment granted under a condition, and a 200-line wizard to walk a human through provisioning
the half of that a deployment template has no business owning. None of that was wrong; there was
just a great deal of it, and all of it had to be kept in someone's head.

**The image did not change, and that is the whole argument.** Not one line of the Dockerfile moved.
ADR-0010 recorded *why* the container holds no certificate in terms of "TLS terminates at the
edge", not "Azure does TLS" — so fly-proxy, which also terminates TLS and hands the container plain
HTTP, satisfies it without an argument. Four of that decision's conclusions carry over untouched:

- **The container holds no TLS of its own.** Same edge arrangement, same reason, same consequence:
  anything that puts this image somewhere without a terminating ingress in front of it is
  publishing cleartext.
- **The image ships no shell.** `fly ssh console` gets exactly what `docker exec` got — nothing.
  Debugging is still logs and endpoints.
- **`/health` is a liveness probe and says nothing about the snapshot.** A BFF that has never
  reached TMDB keeps answering searches honestly with `503` rather than being pulled out of
  rotation, which with one machine would turn a degraded service into a dead one.
- **The store is durable because the thing scales to zero.** ADR-0008's point still stands
  undamaged — the store holds a cache and losing it costs only fetches — and the reason to make it
  durable anyway is still that a container-local store would be emptied on a schedule no one chose.

What is genuinely new is small and all of it is deployment, not application:

**A region-pinned volume replaces the file share.** A 1 GB Fly Volume mounted at `/store`, the same
absolute path Azure Files was mounted at, so nothing in the server had to be told the store moved.
Two differences matter. It is a local filesystem rather than SMB, which retires half of ADR-0010's
reason for a single replica — `File.Move` into place really is an atomic rename now. And it pins
the machine to a physical host with no replication, so losing that host loses the store; under
ADR-0008 that costs fetches, which is why it is acceptable and why Fly's volume snapshots are not
relied on. **One machine is still load-bearing**, on the surviving half of the old reason:
`watch-providers.json` is rewritten wholesale every 24 hours by every machine independently.

**A long-lived deploy token replaces OIDC federation.** Fly offers no GitHub OIDC federation for
deploys, so where Azure had no long-lived credential anywhere, CI now holds an app-scoped Fly
deploy token as a repository secret. This is a real reduction in security posture and is accepted
knowingly: the token deploys one app and can do nothing else in the organisation, and what it
guards is a server holding one TMDB read token and a cache of public logos.

**The TMDB token is set once rather than on every deploy.** Setting a Fly secret restarts the app,
so passing it per-deploy would pay the cold start twice per commit for a value that changes about
once a year. It is set by hand at setup and leaves CI entirely, which also takes a credential out
of CI's blast radius.

## Considered Options

- **Stay on Container Apps.** Rejected on proportion alone, not on anything being broken. It works;
  there is simply far more of it than the server justifies, and every piece is one more thing to
  remember.
- **Ephemeral container-local storage on Fly.** Rejected — this is exactly the option ADR-0010
  weighed and rejected, and nothing about Fly changes the argument. A search sheet asks for twenty
  logos at once, and scale-to-zero would mean re-fetching them on a schedule nobody chose.
- **Object storage (Tigris) instead of a volume.** Rejected: it buys durability without a
  host-pinned machine and it buys multi-writer, but multi-writer is the thing deliberately not
  wanted, and the Logo Store and Poster Store are file-path code that would have to be rewritten to
  reach it. The volume changes the deployment and no application code at all.
- **`flyctl deploy` building the image itself.** Rejected: it is less workflow YAML, but the image
  tag becomes Fly's own release name and the rollback story stops being "pick an older tag". CI
  builds and pushes with the commit SHA as the tag, then deploys by reference.
- **A custom domain.** Rejected for now: the generated `.fly.dev` hostname is the same shape of
  thing as the generated `.azurecontainerapps.io` hostname it replaces, and it is one committed
  default either way.
- **A Fly setup wizard, mirroring the Azure one** (`scripts/azure-setup.sh`, deleted along with the
  estate it provisioned, and reachable in git history). Rejected: that script earned its length by
  walking an Entra directory-permissions minefield where two stages could fail on rights rather
  than on anything being wrong. Fly's setup is five idempotent `flyctl` commands with no
  dashboard and no directory, and a wizard nobody re-runs rots faster than a README section does.

## Consequences

**Deploys are not zero-downtime.** One machine plus one volume means the volume cannot attach
twice, so a blue-green release is impossible and each deploy briefly drops the machine. With
scale-to-zero and a single user this is invisible, but it is a real property and not an oversight.

**Nothing proves the volume is mounted.** The deploy smoke test passes identically with or without
it — an unmounted store just re-fetches on the next cold start, silently, by design. There is no
shell to check with, and an endpoint reporting store state is the thing ADR-0010 declined to
smuggle into liveness. So the mount is verified by hand at setup, platform-side, and a future
`fly.toml` edit could drop it without any test going red. What that failure costs is fetches.

**The health check's grace period is load-bearing and is not the Container App probe's number.**
The Watch Provider refresh is a hosted service, so its first TMDB fetch is awaited before `/health`
answers at all, bounded at 15 seconds. The old probe's 10-second initial delay would fail every
cold start; `fly.toml` uses 30 seconds and says so where someone about to trim it will read it.

**There is a long-lived credential in GitHub now**, which there was not before. Rotating it is
`fly tokens create deploy` and updating one repository secret.
