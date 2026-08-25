# User data lives on the device; the API serves catalog data only

**Status: superseded by [ADR-0005](0005-the-library-is-the-only-store.md).** Kept because it records a road taken and backed out of; the reasoning still bears on how TMDB data is handled.

Season42 is a single-user app with no login. All personal data (Tracked Series, Tracked Movies, Positions) is stored on-device in SwiftData; the ASP.NET Core API is read-only and serves only the shared Catalog. This keeps the API surface tiny and defers auth, per-user storage, and sync-conflict handling until the app ever needs a second client or user.
