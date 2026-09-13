# App Store Connect: the URLs the submission form asks for

App Store Connect will not accept a submission without a privacy policy URL, and asks for a
support URL beside it (issue #114). Both are served by GitHub Pages from this repository —
`site/` in the tree, deployed by `.github/workflows/pages.yml` on every push to `main` that
touches it.

| App Store Connect field | Value |
| --- | --- |
| Privacy Policy URL | `https://arveh.github.io/Season42/privacy/` |
| Support URL | `https://arveh.github.io/Season42/support/` |
| Marketing URL (optional) | `https://arveh.github.io/Season42/` |

The paths are directories rather than `.html` files so the addresses stay stable if the pages
are ever rebuilt by something other than a copy of `site/`.

## What the privacy policy claims, and where each claim lives

Every claim on the policy page is checkable against this repository, and a change to any of
these is a change the page has to follow:

| Claim | Where it is true |
| --- | --- |
| The library never leaves the device | `app/Season42/` — SwiftData, and ADR-0005 |
| Only searching uses the network | `app/Season42/Bff/BffClient.swift` is the only thing that touches it |
| Search text is sent to `season42-bff.fly.dev` | `app/Config/Bff.xcconfig` |
| Search text is logged only when TMDB could not be asked | `bff/Season42.Bff/Program.cs` — the `LogWarning` in each search handler |
| The server stores no user data | `bff/Season42.Bff/` — the only stores are `LogoStore`, `PosterStore` and `WatchProviderStore` |
| The caller's address is counted, not stored | `bff/Season42.Bff/RateLimiting.cs`, and ADR-0017 |
| No analytics, no third-party SDKs | No SPM dependencies in `app/Season42.xcodeproj` |

## The Privacy Nutrition Label that goes with it

Not decided here, but the policy above is what it has to agree with. Apple counts data as
*collected* when it is transmitted off the device **and** kept for longer than it takes to
answer the request. Search text is transmitted, and it is normally not kept — the exception is
the warning logged when TMDB could not be asked, which keeps the text that was searched for.
Whether that exception makes "Search History" a collected type, or whether removing the text
from that log line is the cheaper answer, is a decision to take with issue #119 rather than one
to assume here. Nothing else in the app is a candidate: there is no account, no identifier, no
analytics and no tracking.
