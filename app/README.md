# Season42 iOS app

SwiftUI iPhone app (bundle id `com.season42.app`). Targets: `Season42` (app) and `Season42Tests` (Swift Testing, hosted in the app).

Both targets use filesystem-synchronized groups — files added under `Season42/` or `Season42Tests/` join the right target automatically; no pbxproj edits needed.

## Build and test from the CLI

Requires an Xcode with a usable iOS simulator runtime. If the `xcode-select`ed Xcode has none (symptom: `xcodebuild` reports no eligible simulator destinations), point `DEVELOPER_DIR` at one that does, e.g. `/Applications/Xcode.app/Contents/Developer`.

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
