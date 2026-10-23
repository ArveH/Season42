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

## One-time setup

`./icloud-setup.sh` walks you through it: the iCloud container and App ID in the developer
portal, a real iPhone plus a simulator signed into the same Apple ID, and a signed device build.
Sync between two simulators is unreliable, so use a real device for at least one side. It saves
the device and simulator UDIDs to `.env` here (gitignored).

## Build and run

```sh
cd app/Spikes/CloudKitSpike
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CloudKitSpike.xcodeproj -scheme CloudKitSpike \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -allowProvisioningUpdates build
```

**Sync is off and the store is empty by default.** A plain launch only checks the iCloud
account, and nothing reaches CloudKit until you seed and turn sync on (protocol below).

Launch arguments override the on-screen toggles for one launch: `-syncOn YES|NO`,
`-seedIfEmpty YES`, `-wipeStore YES`. From the command line (with `DEVELOPER_DIR` set as above):

```sh
# iPhone: devicectl needs -- before the app's arguments
xcrun devicectl device process launch --device <iPhone UDID> --terminate-existing \
  com.season42.app.cloudkitspike -- -syncOn YES
# Simulator: simctl passes them straight through
xcrun simctl launch --terminate-running-process <simulator UDID> \
  com.season42.app.cloudkitspike -syncOn YES
# Read the report off the iPhone
xcrun devicectl device copy from --device <iPhone UDID> --domain-type appDataContainer \
  --domain-identifier com.season42.app.cloudkitspike \
  --source Documents/spike-report.txt --destination spike-report.txt
```

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

**Seeing it in the CloudKit Console** (<https://icloud.developer.apple.com/dashboard/>): pick
`iCloud.com.season42.app.cloudkitspike` → **Development**. Record types show under
**Schema → Record Types** after the first export. Records are under **Records**, in the
**Private** database and zone `com.apple.coredata.cloudkit.zone` (not `_defaultZone`), and only
show when you're signed in as the test Apple ID. If a query says "recordName is not marked
queryable", add a Queryable index on `recordName` for that type under **Schema → Indexes**. Only
the Console needs it.

## Findings so far

- An array-literal default (`var seasons: Seasons = [1]`) makes SwiftData trap at launch with
  "Composite Coder only supports Keyed Container". Write it as `Seasons(episodeCounts: [1])`.
  This matters for #138, where every stored property needs a default.
