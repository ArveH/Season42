// PROTOTYPE — the CloudKit spike for #137. Throwaway; never merged to main.
//
// Everything the spike does, and everything it has seen, in one place. Every change rewrites
// `Documents/spike-report.txt`, so a run can be read off the device as well as off the screen.

import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SpikeLab {
    static let containerID = "iCloud.com.season42.app.cloudkitspike"

    /// Launch arguments override these for one launch (`-syncOn YES`), the toggles persist them.
    static var syncOn: Bool { UserDefaults.standard.bool(forKey: "syncOn") }

    let container: ModelContainer
    let syncWasOn: Bool
    var account = "checking…"
    var counts = ""
    var differences: [String] = []
    var events: [String] = []
    var cloud: [String] = ["(not inspected yet)"]
    var notes: [String] = []

    static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "PROTOTYPE-cloudkit-spike.store")
    }

    init() {
        syncWasOn = Self.syncOn
        var wiped = false
        if UserDefaults.standard.bool(forKey: "wipeStore") {
            Self.wipeStoreFiles()
            UserDefaults.standard.set(false, forKey: "wipeStore")
            wiped = true
        }
        let config = ModelConfiguration(
            url: Self.storeURL,
            cloudKitDatabase: syncWasOn ? .private(Self.containerID) : .none)
        do {
            container = try ModelContainer(
                for: TrackedSeries.self, TrackedMovie.self, StreamingService.self,
                configurations: config)
        } catch {
            fatalError("Spike store didn't open: \(error)")
        }
        if wiped { notes.append("Wiped the local store before opening it.") }
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated { self?.record(event) }
        }
        if UserDefaults.standard.bool(forKey: "seedIfEmpty") { seedIfEmpty() }
        refresh()
        Task { await checkAccount() }
    }

    private static func wipeStoreFiles() {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        for name in (try? fm.contentsOfDirectory(atPath: dir.path(percentEncoded: false))) ?? []
        where name.hasPrefix(base) || name.hasPrefix(".PROTOTYPE-cloudkit-spike") {
            try? fm.removeItem(at: dir.appending(path: name))
        }
        // CloudKit mirroring keeps its own metadata beside the store.
        try? fm.removeItem(at: dir.appending(path: "PROTOTYPE-cloudkit-spike_ckAssets"))
    }

    var context: ModelContext { container.mainContext }

    func seedIfEmpty() {
        let existing = (try? context.fetchCount(FetchDescriptor<TrackedSeries>())) ?? 0
        guard existing == 0 else {
            notes.append("Seed skipped: the store already holds \(existing) series.")
            return
        }
        do {
            try Fixture.seed(into: context)
            notes.append("Seeded the fixture at \(Date().formatted(date: .omitted, time: .standard)).")
        } catch {
            notes.append("Seed failed: \(error)")
        }
        refresh()
    }

    /// One edit a second device should see: Alpha's Position moves on one episode, and back
    /// again on the next tap.
    func toggleAlphaPosition() {
        let all = (try? context.fetch(FetchDescriptor<TrackedSeries>())) ?? []
        guard let alpha = all.first(where: { $0.title == "Alpha Watching" }) else { return }
        let fixturePosition = Position(season: 2, episode: 5)
        alpha.position = alpha.position == fixturePosition ? Position(season: 2, episode: 6) : fixturePosition
        try? context.save()
        notes.append("Alpha's Position is now \(alpha.position?.shorthand ?? "nil").")
        refresh()
    }

    func refresh() {
        let s = (try? context.fetchCount(FetchDescriptor<TrackedSeries>())) ?? -1
        let m = (try? context.fetchCount(FetchDescriptor<TrackedMovie>())) ?? -1
        let v = (try? context.fetchCount(FetchDescriptor<StreamingService>())) ?? -1
        counts = "\(s) series, \(m) movies, \(v) services"
        differences = (try? Fixture.differences(in: context)) ?? ["✗ couldn't read the store"]
        writeReport()
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        let kind = switch event.type {
        case .setup: "setup"
        case .import: "import"
        case .export: "export"
        @unknown default: "other"
        }
        let time = event.startDate.formatted(date: .omitted, time: .standard)
        let state = event.endDate == nil ? "started" : (event.succeeded ? "succeeded" : "FAILED")
        var line = "\(time) \(kind) \(state)"
        if let error = event.error { line += " — \(error.localizedDescription) \((error as NSError).userInfo)" }
        events.append(line)
        print("[Spike] event \(line)")
        if event.endDate != nil {
            // An import may have brought new rows; a clean context sees them on the next fetch.
            refresh()
        }
    }

    func checkAccount() async {
        do {
            let status = try await CKContainer(identifier: Self.containerID).accountStatus()
            account = switch status {
            case .available: "available"
            case .noAccount: "NO ACCOUNT — sign into iCloud in Settings"
            case .restricted: "restricted"
            case .couldNotDetermine: "could not determine"
            case .temporarilyUnavailable: "temporarily unavailable"
            @unknown default: "unknown"
            }
        } catch {
            account = "error: \(error.localizedDescription)"
        }
        writeReport()
    }

    /// What CloudKit itself holds: every record in the zone SwiftData mirrors into, with each
    /// field's key and the kind of value stored there. Answers how the Codable values were
    /// written and whether Posters and Logos went up as assets.
    func inspectCloud() async {
        cloud = ["inspecting…"]
        let db = CKContainer(identifier: Self.containerID).privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        var lines: [String] = []
        var token: CKServerChangeToken?
        do {
            var more = true
            while more {
                let changes = try await db.recordZoneChanges(inZoneWith: zone, since: token)
                for (_, result) in changes.modificationResultsByID {
                    switch result {
                    case .success(let modification): lines.append(contentsOf: describe(modification.record))
                    case .failure(let error): lines.append("record error: \(error)")
                    }
                }
                token = changes.changeToken
                more = changes.moreComing
            }
            cloud = lines.isEmpty ? ["The zone exists but holds no records."] : lines
        } catch {
            cloud = ["CloudKit read failed: \(error)"]
        }
        writeReport()
    }

    private func describe(_ record: CKRecord) -> [String] {
        let title = (record["CD_title"] as? String) ?? (record["CD_name"] as? String) ?? record.recordID.recordName
        var lines = ["• \(record.recordType) \"\(title)\""]
        for key in record.allKeys().sorted() {
            let value = record[key]
            let shown: String = switch value {
            case let asset as CKAsset:
                "ASSET (\(Self.assetSize(asset)) bytes)"
            case let data as Data:
                data.count <= 200 ? "bytes(\(data.count)) \(String(decoding: data, as: UTF8.self))" : "bytes(\(data.count))"
            case let string as String:
                "string \"\(string.prefix(80))\""
            case let date as Date:
                "date \(date.ISO8601Format())"
            case let number as NSNumber:
                "number \(number)"
            case let reference as CKRecord.Reference:
                "reference \(reference.recordID.recordName)"
            case let list as [Any]:
                "list(\(list.count)) \(list.prefix(10))"
            case nil:
                "nil"
            default:
                "\(type(of: value!)) \(String(describing: value!).prefix(80))"
            }
            lines.append("    \(key) = \(shown)")
        }
        return lines
    }

    private static func assetSize(_ asset: CKAsset) -> String {
        guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return "?" }
        return String(data.count)
    }

    func writeReport() {
        var lines = [
            "Season42 CloudKit spike report — \(Date().ISO8601Format())",
            "sync this launch: \(syncWasOn ? "ON (\(Self.containerID))" : "off")",
            "iCloud account: \(account)",
            "store: \(counts)",
            "fixture check: \(differences.isEmpty ? "PASS — every value and link matches" : "\(differences.count) difference(s)")",
        ]
        lines += differences.map { "  \($0)" }
        lines += ["", "notes:"] + notes.map { "  \($0)" }
        lines += ["", "CloudKit events:"] + events.map { "  \($0)" }
        lines += ["", "CloudKit records:"] + cloud.map { "  \($0)" }
        let text = lines.joined(separator: "\n")
        try? text.write(to: URL.documentsDirectory.appending(path: "spike-report.txt"), atomically: true, encoding: .utf8)
    }
}
