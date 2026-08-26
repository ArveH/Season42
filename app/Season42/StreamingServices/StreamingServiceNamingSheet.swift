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

    var title: String {
        switch self {
        case .adding: "New streaming service"
        case .renaming: "Rename streaming service"
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
}

extension View {
    /// The one sheet that names a service, wherever the user reached it from — the tab,
    /// or the picker in an entry form. Reports what `Library` refuses rather than showing
    /// it, because the two callers surface a failure in their own alert.
    ///
    /// - Parameter logos: where a search for a Logo gets its answers. The default is the
    ///   live BFF, so both entry points get the search without knowing there is a network.
    func streamingServiceNamingSheet(
        naming: Binding<ServiceNaming?>,
        library: Library,
        logos: any LogoSearching = LogoApi(),
        onFailure: @escaping (String) -> Void,
        onNamed: @escaping (StreamingService) -> Void = { _ in }
    ) -> some View {
        modifier(
            StreamingServiceNamingSheetModifier(
                naming: naming,
                library: library,
                logos: logos,
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
    let onFailure: (String) -> Void
    let onNamed: (StreamingService) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $naming) { naming in
            StreamingServiceNamingSheet(naming: naming, logos: logos) { name, logo in
                submit(naming, as: name, with: logo)
            }
        }
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

/// The sheet itself: a name, a search for a Logo to go with it, and both saved or
/// abandoned together. A sheet rather than an alert because an alert holds a text field
/// and nothing else, and the search needs more room than that.
///
/// Every rule about the search is `LogoSearch`'s. This renders what it says and reports
/// what the user did to it.
struct StreamingServiceNamingSheet: View {
    let naming: ServiceNaming

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
        onSave: @escaping (String, Data?) -> Void
    ) {
        self.naming = naming
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
                logoImage(search.logo)
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
                Text("No streaming service matched that name. Try another spelling, or save without a logo.")
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
                logoImage(match.logo)
                    .frame(width: 44)
                    .accessibilityHidden(true)
                Text(match.name)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Logo bytes drawn at the row height, or the `tv` stand-in where there are none or
    /// they won't decode — the same two halves of a Logo slot the rest of the app draws.
    @ViewBuilder
    private func logoImage(_ logo: Data?) -> some View {
        if let logo, let image = UIImage(data: logo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
        } else {
            Image(systemName: "tv")
                .foregroundStyle(.secondary)
                .frame(height: logoHeight)
        }
    }

    private func runSearch() {
        Task { await search.search() }
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
        if fails { throw LogoError.notServed(status: 503) }
        return matches
    }

    func logo(at path: String) async throws -> Data {
        PreviewLogo.bytes(path.contains("ads") ? .systemOrange : .systemRed)
    }
}
