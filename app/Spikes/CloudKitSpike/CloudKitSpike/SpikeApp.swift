// PROTOTYPE — the CloudKit spike for #137. Throwaway; never merged to main.

import SwiftUI

@main
struct SpikeApp: App {
    @State private var lab = SpikeLab()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            SpikeView(lab: lab)
                .onChange(of: phase) { _, now in if now == .active { lab.refresh() } }
        }
    }
}

struct SpikeView: View {
    let lab: SpikeLab
    @State private var syncNext = SpikeLab.syncOn
    @State private var wipeNext = false

    var body: some View {
        NavigationStack {
            List {
                Section("This launch") {
                    LabeledContent("Sync", value: lab.syncWasOn ? "ON" : "off")
                    LabeledContent("iCloud account", value: lab.account)
                    LabeledContent("Store", value: lab.counts)
                }
                Section("Fixture check") {
                    if lab.differences.isEmpty {
                        Text("PASS — every value and link matches").foregroundStyle(.green)
                    } else {
                        ForEach(lab.differences, id: \.self) { Text($0).font(.caption.monospaced()) }
                    }
                }
                Section("Actions") {
                    Button("Seed fixture (if empty)") { lab.seedIfEmpty() }
                    Button("Move Alpha's Position") { lab.toggleAlphaPosition() }
                    Button("Re-check store") { lab.refresh() }
                    Button("Inspect CloudKit") { Task { await lab.inspectCloud() } }
                }
                Section("Next launch (quit and relaunch to apply)") {
                    Toggle("Sync on", isOn: $syncNext)
                        .onChange(of: syncNext) { _, on in UserDefaults.standard.set(on, forKey: "syncOn") }
                    Toggle("Wipe local store first", isOn: $wipeNext)
                        .onChange(of: wipeNext) { _, on in UserDefaults.standard.set(on, forKey: "wipeStore") }
                }
                Section("Notes") { ForEach(lab.notes, id: \.self) { Text($0).font(.caption) } }
                Section("CloudKit events") { ForEach(lab.events, id: \.self) { Text($0).font(.caption.monospaced()) } }
                Section("CloudKit records") { ForEach(lab.cloud, id: \.self) { Text($0).font(.caption2.monospaced()) } }
            }
            .navigationTitle("CloudKit spike")
        }
    }
}
