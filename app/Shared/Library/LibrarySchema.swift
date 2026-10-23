import SwiftData

/// The Library's schema as it stood when it was first versioned: Tracked Series, Tracked
/// Movie and Streaming Service as they were before (ADR-0023). The models are declared
/// inside this enum, in their own files, and the rest of the app names them through the
/// typealiases below, so V1 is a version of its own rather than whatever the models are
/// today.
///
/// V1 is frozen: once a store has been written with it, its hash must never change, or
/// that store fails to open and is kept aside. A change to the models is a new version —
/// copy these classes into `LibrarySchemaV2`, change the copies, point the typealiases at
/// them and add the stage to `LibraryMigrationPlan` — and never an edit to the classes
/// here. The value types they store (`Seasons`, `WatchStatus`, `Position`, `ReleaseSlot`)
/// are part of that hash too, and are frozen with them.
enum LibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrackedSeries.self, TrackedMovie.self, StreamingService.self]
    }
}

/// The models of the current schema version, under the names the rest of the app uses.
typealias TrackedSeries = LibrarySchemaV1.TrackedSeries
typealias TrackedMovie = LibrarySchemaV1.TrackedMovie
typealias StreamingService = LibrarySchemaV1.StreamingService

/// Every version the Library's store has had, oldest first, and how a store moves from
/// each to the next. A store written before the schema was versioned is V1 as it is, so
/// there is nothing to move yet; each later schema change adds a version and its stage.
enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LibrarySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
