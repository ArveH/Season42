import SwiftData

/// The Library's schema as it stood when it was first versioned: today's Tracked Series,
/// Tracked Movie and Streaming Service, unchanged (ADR-0023). The models are the app's own
/// types rather than copies nested here, so nothing that names them had to change; the
/// version that next changes them is the one that freezes these as V1's own.
enum LibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrackedSeries.self, TrackedMovie.self, StreamingService.self]
    }
}

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
