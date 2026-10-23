# PROTOTYPE: CloudKit spike (#137)

Throwaway code that answers the two questions ADR-0022 left open before #138 builds on them.
It lives on the `prototype/cloudkit-spike` branch and is **never merged to main**. The verdict
goes on #130 as a comment.

1. Do the Codable values (`Seasons`, `Position`, `ReleaseSlot`, `WatchStatus`) round-trip
   through CloudKit sync?
2. Does turning sync on for a store that already holds data upload that data?
3. (Noted.) Do Posters and Logos in external storage go up as CloudKit assets?

## Why it can't touch the real Library

- Its own app (`com.season42.app.cloudkitspike`, shown as **CK Spike**), so its own sandbox and
  its own store file (`PROTOTYPE-cloudkit-spike.store`).
- Its own iCloud container, `iCloud.com.season42.app.cloudkitspike`, in CloudKit's
  **development** environment. Not the container the app will use.
- Test data only, from `Fixture.swift`.

## What it is

The three models reshaped as ADR-0022 says V2 will be (defaults or optionals everywhere,
optional to-many relationships, Posters and Logos in external storage), with the app's own
`Seasons.swift`, `Position.swift`, `ReleaseSlot.swift` and `WatchStatus.swift` compiled in
unchanged. One screen shows:

- **Fixture check**: every value and link in the store compared with the fixture. PASS means
  nothing was lost.
- **CloudKit events**: SwiftData's setup, import and export events, with any error.
- **CloudKit records**: what the CloudKit zone actually holds, field by field, and which
  fields are assets.

Each change also rewrites `Documents/spike-report.txt` in the app's sandbox.

## Build and run

```sh
cd app/Spikes/CloudKitSpike
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CloudKitSpike.xcodeproj -scheme CloudKitSpike \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -allowProvisioningUpdates build
```

Launch arguments override the on-screen toggles for one launch: `-syncOn YES|NO`,
`-seedIfEmpty YES`, `-wipeStore YES`.

## Protocol

The device (simulator or phone) must be signed into iCloud. Any Apple ID works: the data goes
only to the spike's own container.

**Question 2, existing data uploads:**

1. Launch with sync off and seed: `-syncOn NO -seedIfEmpty YES`. The fixture check passes.
2. Relaunch with `-syncOn YES`. Wait for an export event that succeeded.
3. Tap **Inspect CloudKit**. Yes, if 5 `CD_TrackedSeries`, 2 `CD_TrackedMovie` and
   3 `CD_StreamingService` records are listed.

**Question 1, values round-trip:**

4. Relaunch with `-syncOn YES -wipeStore YES`. The local store starts empty and imports from
   CloudKit. Yes, if the fixture check passes after the import event.
5. Better, a second device on the same Apple ID: install, launch with `-syncOn YES` and nothing
   seeded. It imports, and the fixture check passes. **Move Alpha's Position** on one device and
   the other shows the change.

**Question 3:** in the record listing, Poster and Logo fields shown as `ASSET` went up as assets.

## Findings so far

- An array-literal default (`var seasons: Seasons = [1]`) makes SwiftData trap at launch with
  "Composite Coder only supports Keyed Container". Write it as `Seasons(episodeCounts: [1])`.
  This matters for #138, where every stored property needs a default.
