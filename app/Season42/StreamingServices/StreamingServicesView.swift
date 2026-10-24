import SwiftUI

/// The Streaming Services tab: the list of services the user watches on, and the one
/// place they are registered, renamed and removed. Every rule about a name lives in
/// `Library`, and whatever it refuses is shown back to the user verbatim.
struct StreamingServicesView: View {
    let library: Library

    @State private var naming: ServiceNaming?
    @State private var deleting: StreamingService?
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.streamingServices.isEmpty {
                    ContentUnavailableView(
                        "No streaming services yet",
                        systemImage: "tv",
                        description: Text(
                            """
                            Register the services you watch on, and you can pick one for \
                            every series and movie you track.
                            """
                        )
                    )
                } else {
                    List(library.streamingServices) { service in
                        row(for: service)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleting = service
                                }
                                Button("Rename", systemImage: "pencil") {
                                    naming = .renaming(service)
                                }
                                .tint(.accentColor)
                            }
                    }
                }
            }
            .navigationTitle("Streaming Services")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { naming = .adding }
                }
            }
            .streamingServiceNamingSheet(
                naming: $naming,
                library: library,
                offersMerge: true,
                onFailure: { failureMessage = $0 }
            )
            .confirmationDialog(
                "Delete this streaming service?",
                isPresented: .init(
                    get: { deleting != nil },
                    set: { if !$0 { deleting = nil } }
                ),
                presenting: deleting
            ) { service in
                Button("Delete \(service.name)", role: .destructive) {
                    library.deleteStreamingService(service)
                }
            } message: { service in
                deletionWarning(for: service)
            }
            .alert(
                "Couldn't save the streaming service",
                isPresented: .init(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                ),
                presenting: failureMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    /// A row, tappable on its text to rename what it names, showing how many entries name
    /// this service — which is what makes the delete warning below unsurprising.
    private func row(for service: StreamingService) -> some View {
        StreamingServiceRow(
            name: service.name,
            logo: service.logo,
            entryCount: library.entryCount(of: service)
        )
            .contentShape(.rect)
            .onTapGesture { naming = .renaming(service) }
    }

    /// What deleting costs. A service nothing names goes quietly; one that entries name
    /// takes their service with it, and they are counted before the user commits.
    ///
    /// Returns a `Text` rather than a `String` so the count stays in a string literal:
    /// joining one together first would leave the inflection markup to be read as text.
    private func deletionWarning(for service: StreamingService) -> Text {
        let count = library.entryCount(of: service)
        guard count > 0 else { return Text("This can't be undone.") }
        return Text(
            """
            ^[\(count) entry](inflect: true) will be left with no streaming service. \
            Nothing you track is deleted.
            """
        )
    }
}

/// A Streaming Service as the tab draws it: its Logo slot, its name and how many entries
/// name it. The list a merge picks its target from draws the same row, so two services
/// with one name can be told apart by their Logo and count.
///
/// The caller asks the Library for the count rather than reading it off the service, so
/// that its list is redrawn when an entry starts or stops naming it (ADR-0018).
///
/// Values rather than the service: the caller reads them while drawing its list, so a
/// change to one redraws the list and the row with it. A row holding the model redrew on
/// its own when a merge deleted its service, before the list had dropped it, and reading
/// a deleted service's Logo traps (ADR-0025).
///
/// The Logo is drawn beside the name rather than instead of it, as the rows elsewhere
/// do: these are where services are managed, so the name has to stay readable.
struct StreamingServiceRow: View {
    let name: String
    let logo: Data?
    let entryCount: Int

    /// The Logo slot grows with the name beside it.
    @ScaledMetric(relativeTo: .body) private var logoHeight = 24

    var body: some View {
        HStack {
            StreamingServiceLogo(logo: logo, height: logoHeight)
                .frame(width: 44)
                // The name is right beside it, so the slot has nothing of its own to say.
                .accessibilityHidden(true)
            Text(name)
            Spacer()
            Text("^[\(entryCount) entry](inflect: true)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StreamingServicesView(library: previewLibrary())
}

/// Services as the tab shows them: with a Logo and without, so both halves of a Logo slot
/// are visible without a BFF running behind the preview.
@MainActor
private func previewLibrary() -> Library {
    let library = try! Library.inMemory()
    try! library.addStreamingService(name: "Apple TV+", logo: PreviewLogo.bytes(.systemIndigo))
    try! library.addStreamingService(name: "Netflix", logo: PreviewLogo.bytes(.systemRed))
    try! library.addStreamingService(name: "NRK TV")
    return library
}
