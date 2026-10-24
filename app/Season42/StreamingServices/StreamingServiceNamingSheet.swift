import SwiftData
import SwiftUI

/// Whether the user is registering a service or renaming one they have. Both take a
/// single name and a Logo, so both are the same sheet.
enum ServiceNaming: Identifiable {
    case adding
    case renaming(StreamingService)

    var id: String {
        switch self {
        case .adding: "adding"
        case .renaming(let service): "\(service.persistentModelID)"
        }
    }

    /// Kept short enough to survive an inline title bar with a button on either side:
    /// "Rename streaming service" doesn't fit between Cancel and Save, and SwiftUI drops
    /// a title it can't fit rather than truncating it, leaving the sheet unlabelled.
    var title: String {
        switch self {
        case .adding: "New service"
        case .renaming: "Rename service"
        }
    }

    /// What the name field starts out holding: nothing for a new service, the current
    /// name for one being renamed.
    var currentName: String {
        switch self {
        case .adding: ""
        case .renaming(let service): service.name
        }
    }

    /// The Logo the sheet opens with — none for a new service, the adopted one for a
    /// service being renamed, which is what leaves it alone unless the user changes it.
    var currentLogo: Data? {
        switch self {
        case .adding: nil
        case .renaming(let service): service.logo
        }
    }

    /// The services this one can be merged into, in the order `services` lists them: every
    /// other one, not only those with a similar name, since which two are the same service
    /// is the user's call (ADR-0025). None for a service still being added, which has
    /// nothing stored to merge.
    ///
    /// Told apart by persistent ID: the sheet may hold the service from before a sync
    /// (ADR-0024).
    func mergeTargets(in services: [StreamingService]) -> [StreamingService] {
        guard case .renaming(let service) = self else { return [] }
        let id = service.persistentModelID
        return services.filter { $0.persistentModelID != id }
    }
}

extension View {
    /// The one sheet that names a service, wherever the user reached it from — the tab,
    /// or the picker in an entry form. Reports what `Library` refuses rather than showing
    /// it, because the two callers surface a failure in their own alert.
    ///
    /// - Parameters:
    ///   - logos: where a search for a Logo gets its answers. The default is the live BFF,
    ///     so both entry points get the search without knowing there is a network.
    ///   - offersMerge: whether a service being renamed can be merged into another from
    ///     here. Only the Streaming Services tab offers it, not the picker in an entry form.
    func streamingServiceNamingSheet(
        naming: Binding<ServiceNaming?>,
        library: Library,
        logos: any LogoSearching = BffClient(),
        offersMerge: Bool = false,
        onFailure: @escaping (String) -> Void,
        onNamed: @escaping (StreamingService) -> Void = { _ in }
    ) -> some View {
        modifier(
            StreamingServiceNamingSheetModifier(
                naming: naming,
                library: library,
                logos: logos,
                offersMerge: offersMerge,
                onFailure: onFailure,
                onNamed: onNamed
            )
        )
    }
}

/// Presents the sheet and is the only thing that touches `Library`, so the sheet itself
/// gathers a name and a Logo and decides nothing.
private struct StreamingServiceNamingSheetModifier: ViewModifier {
    @Binding var naming: ServiceNaming?
    let library: Library
    let logos: any LogoSearching
    let offersMerge: Bool
    let onFailure: (String) -> Void
    let onNamed: (StreamingService) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $naming) { naming in
            StreamingServiceNamingSheet(
                naming: naming,
                logos: logos,
                merging: merging(for: naming)
            ) { name, logo in
                submit(naming, as: name, with: logo)
            }
        }
    }

    /// What the sheet needs to offer a merge, or nil where none is offered: from anywhere
    /// but the tab, when adding, when there is no other service to merge into, and once the
    /// service is gone — merged, or deleted on another device.
    ///
    /// Everything the sheet draws is read here off the Library's own listing, never off the
    /// service the sheet was handed: that one may be from before a sync (ADR-0024), or
    /// deleted by the merge while the sheet is still going down, and reading a deleted
    /// service's fields traps.
    private func merging(for naming: ServiceNaming) -> ServiceMerging? {
        guard offersMerge, case .renaming(let held) = naming else { return nil }
        guard let service = library.listedStreamingService(withID: held.persistentModelID)
        else { return nil }
        let targets = naming.mergeTargets(in: library.streamingServices)
        guard !targets.isEmpty else { return nil }
        return ServiceMerging(
            serviceName: service.name,
            entriesToMove: library.entryCount(of: service),
            targets: targets.map {
                ServiceMerging.Target(
                    id: $0.persistentModelID,
                    name: $0.name,
                    logo: $0.logo,
                    entryCount: library.entryCount(of: $0)
                )
            },
            merge: { targetID in
                merge(service, into: targetID)
            }
        )
    }

    /// Merges what is stored, not what the sheet holds: a name typed or a Logo adopted
    /// but not saved is dropped with the sheet, as Cancel would drop it.
    private func merge(_ service: StreamingService, into targetID: PersistentIdentifier) {
        defer { naming = nil }
        guard let target = library.listedStreamingService(withID: targetID) else { return }
        library.mergeStreamingService(service, into: target)
    }

    /// Saves, and takes the sheet down either way — what `Library` refuses is reported to
    /// the caller, whose own alert says it, exactly as it did while this was an alert.
    ///
    /// The name goes first when renaming: a refused rename must leave the service whole,
    /// and a Logo adopted onto a service whose new name was rejected is a change the user
    /// never got to see.
    private func submit(_ naming: ServiceNaming, as name: String, with logo: Data?) {
        defer { self.naming = nil }
        do {
            switch naming {
            case .adding:
                onNamed(try library.addStreamingService(name: name, logo: logo))
            case .renaming(let service):
                try library.renameStreamingService(service, to: name)
                if service.logo != logo {
                    library.setLogo(logo, on: service)
                }
                onNamed(service)
            }
        } catch {
            onFailure(error.localizedDescription)
        }
    }
}

/// What the naming sheet needs to offer merging the service it renames into another: the
/// service's stored name and how many entries would move, the services it can go into, and
/// the merge itself. Everything a merge does is `Library`'s; the sheet only picks the target
/// and confirms.
///
/// Values rather than models, so nothing the sheet draws reads a service the merge has
/// just deleted.
struct ServiceMerging {
    struct Target: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let logo: Data?
        let entryCount: Int
    }

    let serviceName: String
    let entriesToMove: Int
    let targets: [Target]
    let merge: (PersistentIdentifier) -> Void
}

/// The sheet itself: a name, a search for a Logo to go with it, and both saved or
/// abandoned together. A sheet rather than an alert because an alert holds a text field
/// and nothing else, and the search needs more room than that.
///
/// Every rule about the search is `LogoSearch`'s. This renders what it says and reports
/// what the user did to it.
struct StreamingServiceNamingSheet: View {
    let naming: ServiceNaming

    /// How to merge the service into another, or nil where the sheet offers no merge.
    let merging: ServiceMerging?

    /// Called with the typed name and the adopted Logo when the user saves. Whoever
    /// presents the sheet is what takes it down afterwards, because the binding that
    /// holds it up is theirs.
    let onSave: (String, Data?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var search: LogoSearch

    /// The Logo slot on a result row, sized as the Streaming Services tab's is.
    @ScaledMetric(relativeTo: .body) private var logoHeight = 24

    init(
        naming: ServiceNaming,
        logos: any LogoSearching,
        merging: ServiceMerging? = nil,
        onSave: @escaping (String, Data?) -> Void
    ) {
        self.naming = naming
        self.merging = merging
        self.onSave = onSave
        _search = State(
            initialValue: LogoSearch(
                name: naming.currentName,
                logo: naming.currentLogo,
                logos: logos
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                if search.hasLogo {
                    adoptedLogoSection
                }
                resultsSection
                if let merging {
                    mergeSection(merging)
                }
                TmdbAttribution(.watchProviders)
            }
            .navigationTitle(naming.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Enabled whatever is typed and whatever the search is doing: every
                    // rule about a name is `Library`'s, and a service with no Logo is
                    // entirely valid — so a search is never something to wait for.
                    Button("Save") { onSave(search.name, search.logo) }
                }
            }
        }
    }

    /// The name, and the Search button beside it. Searching is what is typed, so the two
    /// belong on one row.
    private var nameSection: some View {
        Section {
            HStack {
                TextField("Name", text: $search.name)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                Button("Search", systemImage: "magnifyingglass") { runSearch() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        } footer: {
            Text("Search for a logo to go with the name, or save without one.")
        }
    }

    /// The Logo in force, and the only way to be rid of one adopted by mistake. Without
    /// it the escape would be deleting the service, which leaves every Library Entry
    /// naming it with none.
    private var adoptedLogoSection: some View {
        Section("Logo") {
            HStack {
                StreamingServiceLogo(logo: search.logo, height: logoHeight)
                Spacer()
                Button("Remove", role: .destructive) { search.removeLogo() }
                    .buttonStyle(.borderless)
            }
        }
    }

    /// What the search has to say, which is nothing at all until one has been run. A
    /// failure is said here rather than in an alert: the alerts around this sheet are for
    /// what `Library` refuses, and a BFF that isn't there refuses nothing.
    @ViewBuilder
    private var resultsSection: some View {
        switch search.state {
        case .idle:
            EmptyView()

        case .searching:
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                }
            }

        case .results(let matches):
            Section("Logos") {
                ForEach(matches) { match in
                    resultRow(match)
                }
            }

        case .matchedNothing:
            Section {
                Text("Nothing matched that name. Try another spelling, or save without a logo.")
                    .foregroundStyle(.secondary)
            }

        case .failed:
            Section {
                Label(
                    "Couldn't reach the logo service. You can still save without a logo.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    /// One match, adopted by tapping it. Nothing marks a row as the one adopted: adopting
    /// fills the name field in, which is where the user is already looking.
    private func resultRow(_ match: WatchProviderMatch) -> some View {
        Button {
            search.adopt(match)
        } label: {
            HStack {
                StreamingServiceLogo(logo: match.logo, height: logoHeight)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                Text(match.name)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        Task { await search.search() }
    }

    /// The way to fix two services that are really one, such as the duplicates an iCloud
    /// sync can bring in (ADR-0025).
    private func mergeSection(_ merging: ServiceMerging) -> some View {
        Section {
            NavigationLink("Merge into…") {
                MergeTargetList(merging: merging)
            }
        } footer: {
            Text("Move every entry on this service to another one, then delete this one.")
        }
    }
}

/// Every other service, drawn as the Streaming Services tab draws it, so that two with one
/// name are told apart by their Logo and count. Picking one asks before anything moves.
private struct MergeTargetList: View {
    let merging: ServiceMerging

    @State private var target: ServiceMerging.Target?

    var body: some View {
        List(merging.targets) { target in
            Button {
                self.target = target
            } label: {
                StreamingServiceRow(
                    name: target.name,
                    logo: target.logo,
                    entryCount: target.entryCount
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Merge into")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Merge into this streaming service?",
            isPresented: .init(
                get: { target != nil },
                set: { if !$0 { target = nil } }
            ),
            presenting: target
        ) { target in
            Button("Merge into \(target.name)", role: .destructive) {
                merging.merge(target.id)
            }
        } message: { target in
            mergeWarning(into: target)
        }
    }

    /// What merging does, counted by the Library as the delete confirmation counts
    /// (ADR-0018). Named by the stored name, since a name typed but not saved goes with
    /// the sheet.
    ///
    /// Returns a `Text` rather than a `String` so the count stays in a string literal, for
    /// the inflection markup.
    private func mergeWarning(into target: ServiceMerging.Target) -> Text {
        let count = merging.entriesToMove
        let name = merging.serviceName
        guard count > 0 else {
            return Text(
                """
                No entries will move to \(target.name). \(name) will be deleted. This can't be \
                undone.
                """
            )
        }
        return Text(
            """
            ^[\(count) entry](inflect: true) will move to \(target.name), and \(name) will be \
            deleted. This can't be undone.
            """
        )
    }
}

#Preview("Adding") {
    StreamingServiceNamingSheet(naming: .adding, logos: PreviewLogos()) { _, _ in }
}

#Preview("Renaming") {
    StreamingServiceNamingSheet(
        naming: .renaming(StreamingService(name: "Netflix", logo: PreviewLogo.bytes(.systemRed))),
        logos: PreviewLogos()
    ) { _, _ in }
}

#Preview("Nothing matched") {
    StreamingServiceNamingSheet(naming: .adding, logos: PreviewLogos(matches: [])) { _, _ in }
}

#Preview("Unreachable") {
    StreamingServiceNamingSheet(naming: .adding, logos: PreviewLogos(fails: true)) { _, _ in }
}

/// A BFF for the previews above, so every state of the search can be seen without one
/// running. Not behind `#if DEBUG`: a `#Preview` is compiled in every configuration, so
/// what it calls has to be too.
private struct PreviewLogos: LogoSearching {
    var matches: [WatchProvider] = [
        WatchProvider(name: "Netflix", logoPath: "/netflix.jpg"),
        WatchProvider(name: "Netflix basic with Ads", logoPath: "/netflix-ads.jpg"),
    ]
    var fails = false

    func providers(matching text: String) async throws -> [WatchProvider] {
        if fails { throw BffError.notServed(status: 503) }
        return matches
    }

    func logo(at path: String) async throws -> Data {
        PreviewLogo.bytes(path.contains("ads") ? .systemOrange : .systemRed)
    }
}
