# User data lives on the device; the API serves catalog data only

Season42 is a single-user app with no login. All personal data (Tracked Series, Tracked Movies, Positions) is stored on-device in SwiftData; the ASP.NET Core API is read-only and serves only the shared Catalog. This keeps the API surface tiny and defers auth, per-user storage, and sync-conflict handling until the app ever needs a second client or user.
