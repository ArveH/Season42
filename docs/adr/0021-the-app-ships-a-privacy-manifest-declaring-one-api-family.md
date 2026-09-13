# The app ships a privacy manifest, and it declares one API family

Apple enforces `PrivacyInfo.xcprivacy` for third-party SDKs. This app ships none — it has no
package dependencies at all — so nothing is rejected today for its absence, and the question is
not whether the app is allowed to submit without one but whether the answers should be written
down anywhere other than the submission form.

**The app ships one.** It costs a single file that nothing at runtime reads, and it turns the App
Privacy answers from something reconstructed at each submission into something that is in the
repo, reviewed in a diff, and asserted by a test. The alternative is not "no manifest" — the same
questions get answered either way — it is answering them from memory once a year.

**It declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`, and nothing else.**
`CA92.1` is the "access information from the app itself" case, and it is the only way this app uses
`UserDefaults`: the Appearance setting and the Watching Order, both the user's own and both read
back only by the app that wrote them ([ADR-0014](0014-the-watching-order-is-the-users-and-held-still.md)).
There is no app group, no shared container, no extension reading a suite the app wrote — so no
other reason applies and none is claimed.

**The file timestamp family is not declared, because the app does not use it.** The ticket that
asked for this decision named two families, timestamps via `FileManager` being the second, and that
half of the premise did not survive being checked. The app's only `FileManager` calls are in
discarding an unopenable Library store ([ADR-0009](0009-an-unopenable-library-store-is-discarded.md)):
a `contentsOfDirectory(at:includingPropertiesForKeys: nil)` and a `removeItem(at:)`. Neither reads
a timestamp, and passing `nil` for the keys is what makes that plain — nothing is asked for. The
timestamps that do exist in this project are the BFF's, where a stored image's `mtime` is its age
([ADR-0020](0020-image-lifetime-is-a-setting-capped-at-six-months.md)), and the BFF is a server: it
is not submitted to anyone and has no manifest to put them in.

**Declaring a family the binary does not use would be the wrong kind of caution.** The manifest is
a statement about this app, and a statement that is wider than the truth is still wrong — it also
makes the file useless as a record, because a reader can no longer tell which entries were put
there by a use and which by a shrug. An entry earns its place when a call site exists.

**Data collection is none, and the file says so in three places rather than by omission.**
`NSPrivacyTracking` is `false`, `NSPrivacyTrackingDomains` is empty, and `NSPrivacyCollectedDataTypes`
is empty. The empty arrays are the point: a missing key is a question left open, and an empty one
is an answer. It is also simply what the app is — everything it knows is entered by hand and kept
on the device ([ADR-0001](0001-user-data-on-device-api-serves-catalog-only.md)), and the only thing
it reaches the network for is a search, which goes to the BFF
([ADR-0007](0007-a-bff-fetches-provider-logos-the-app-keeps-the-bytes.md)) and carries a title the
user typed and nothing about the user.

**The manifest is enforced by a test against the built bundle, not against the source tree.** It
lives in `Season42/`, which is a filesystem-synchronized group, so it joins the app target by being
there and no pbxproj edit carries it. That convenience is exactly why the test reads
`Bundle.main.url(forResource:withExtension:)` instead of a path in the repo: a manifest that is in
the checkout but not in the `.app` declares nothing to anyone, and the file is otherwise unreachable
from any code path that could notice it going missing. `PrivacyManifestTests` asserts that the
bundle ships it, that it collects nothing and tracks nobody, that `UserDefaults` is declared with
`CA92.1` — and that the accessed-API list contains nothing else, so a family arriving without a
decision behind it fails rather than passes quietly.

## Considered Options

- **No manifest, and a comment on the ticket recording why.** The ticket offered this as an equally
  closing outcome and it is a defensible one: nothing requires the file, and an app with no
  dependencies will not acquire the requirement by accident. Rejected because the comment and the
  file cost the same to write and only one of them is still there at the next submission, in the
  place someone would look. A decision recorded only in an issue comment is a decision that gets
  rediscovered.
- **Declare both families the ticket named.** Rejected: see above — the second one has no call site.
  It would have been the easy way to satisfy the acceptance criterion as literally written, at the
  cost of the file no longer describing the app.
- **Declare the family, but with every plausible reason code rather than the one that applies.**
  Rejected for the same reason, one level down. `CA92.1` is a claim about how the app reads what it
  wrote; adding the app-group reasons beside it would claim a shape this app does not have.
- **Keep the manifest and skip the test.** Rejected: nothing in the app reads this file, so nothing
  else can notice it being dropped from the target, renamed, or edited into something it did not
  say. A resource with no reader is exactly the case a bundle test is for, and there is precedent —
  `AppBuildTests` asserts the real bundle answers with the keys the build generates.
- **Put it in `Config/` beside `Info.plist`.** Rejected: `Config/` holds what the build is *told*,
  one file per concern, and each of those files is named in the pbxproj or an xcconfig. The manifest
  is a resource the app *ships*, and putting it under `Season42/` is what gets it copied without a
  project edit.

## Consequences

The app now has a bundled resource beyond its asset catalog, which `app/README.md` said it did not;
that sentence is corrected rather than left to mislead the next person adding one.

The App Privacy answers at submission are now a thing to be read off a file rather than recalled:
data not collected, no tracking, `UserDefaults` accessed for the app's own information.

Adding a package dependency later changes the calculation but not this decision — a third-party SDK
brings its own manifest, and Apple's requirement lands on that SDK. What would change this file is
the app itself reaching for another required-reason family, and `itDeclaresNothingElse` is what
makes that a failing test rather than an omission.
