# Season42 iOS app

SwiftUI iPhone app (bundle id `com.season42.app`). Targets: `Season42` (app) and `Season42Tests` (Swift Testing, hosted in the app).

Both targets use filesystem-synchronized groups — files added under `Season42/` or `Season42Tests/` join the right target automatically; no pbxproj edits needed. There is nothing else in either target: the app has no bundled resources beyond its asset catalog.

The one thing it reaches the network for is searching for a Streaming Service's Logo, which goes to the BFF (ADR-0007) — see `bff/README.md`. Everything else works with the BFF stopped, an adopted Logo included, because the bytes are on the device.

## Build and test from the CLI

Requires an Xcode that is recent enough to open the project *and* has a usable iOS simulator runtime. Point `DEVELOPER_DIR` at one that does — e.g. `/Applications/Xcode.app/Contents/Developer` — when the `xcode-select`ed Xcode reports either:

- `cannot be opened because it is in a future Xcode project file format` — that Xcode is older than the one the project was last saved with, or
- no eligible simulator destinations.

```sh
xcodebuild -project Season42.xcodeproj -scheme Season42 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # or: test
```

## Run in the simulator

```sh
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl install booted <path to Season42.app from DerivedData>
xcrun simctl launch booted com.season42.app
```
