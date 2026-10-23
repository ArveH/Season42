import Foundation
import SwiftData

/// The Library's schema made iCloud-ready (ADR-0022): every stored property optional or
/// defaulted, the Streaming Service's relationships optional, no unique constraints, and
/// Posters and Logos in external storage. The models are declared inside this enum, in
/// their own files, and the rest of the app names them through the typealiases below.
///
/// Frozen once a store has been written with it, as V1 is: a change to the models is a new
/// version — move these classes into a frozen `LibrarySchemaV2.swift` the way V1's were,
/// declare the next version in the model files, point the typealiases at it and add the
/// stage to `LibraryMigrationPlan` — and never an edit to a version a store already has.
/// Once this schema is in CloudKit's production environment, a later version may only add
/// to it: nothing is renamed, removed or retyped (ADR-0022).
enum LibrarySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrackedSeries.self, TrackedMovie.self, StreamingService.self]
    }
}

/// The models of the current schema version, under the names the rest of the app uses.
typealias TrackedSeries = LibrarySchemaV2.TrackedSeries
typealias TrackedMovie = LibrarySchemaV2.TrackedMovie
typealias StreamingService = LibrarySchemaV2.StreamingService

/// Every version the Library's store has had, oldest first, and how a store moves from
/// each to the next. A store written before the schema was versioned is V1 as it is.
enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LibrarySchemaV1.self, LibrarySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// V2 only loosens what V1 required and moves the images out of the rows, so SwiftData
    /// infers the move of every value. But moving an image to external storage turns one
    /// that was nil into zero bytes, and a row would draw that as a Poster or Logo rather
    /// than the placeholder. No adopted image is ever empty, so after the move an empty one
    /// is put back to nil.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: LibrarySchemaV1.self,
        toVersion: LibrarySchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            for series in try context.fetch(FetchDescriptor<LibrarySchemaV2.TrackedSeries>())
            where series.poster?.isEmpty == true {
                series.poster = nil
            }
            for movie in try context.fetch(FetchDescriptor<LibrarySchemaV2.TrackedMovie>())
            where movie.poster?.isEmpty == true {
                movie.poster = nil
            }
            for service in try context.fetch(FetchDescriptor<LibrarySchemaV2.StreamingService>())
            where service.logo?.isEmpty == true {
                service.logo = nil
            }
            try context.save()
        }
    )
}
