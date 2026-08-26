import SwiftUI

/// Whether the user is registering a service or renaming one they have. Both take a
/// single name, so both are the same sheet.
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
}

extension View {
    /// The one sheet that names a service, wherever the user reached it from — the tab,
    /// or the picker in an entry form. Reports what `Library` refuses rather than showing
    /// it, because the two callers surface a failure in their own alert.
    func streamingServiceNamingSheet(
        naming: Binding<ServiceNaming?>,
        library: Library,
        onFailure: @escaping (String) -> Void,
        onNamed: @escaping (StreamingService) -> Void = { _ in }
    ) -> some View {
        modifier(
            StreamingServiceNamingSheetModifier(
                naming: naming,
                library: library,
                onFailure: onFailure,
                onNamed: onNamed
            )
        )
    }
}

/// Presents the sheet and is the only thing that touches `Library`, so the sheet itself
/// gathers a name and decides nothing.
private struct StreamingServiceNamingSheetModifier: ViewModifier {
    @Binding var naming: ServiceNaming?
    let library: Library
    let onFailure: (String) -> Void
    let onNamed: (StreamingService) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $naming) { naming in
            StreamingServiceNamingSheet(naming: naming) { name in
                submit(naming, as: name)
            }
        }
    }

    /// Saves, and takes the sheet down either way — what `Library` refuses is reported to
    /// the caller, whose own alert says it, exactly as it did while this was an alert.
    private func submit(_ naming: ServiceNaming, as name: String) {
        defer { self.naming = nil }
        do {
            switch naming {
            case .adding:
                onNamed(try library.addStreamingService(name: name))
            case .renaming(let service):
                try library.renameStreamingService(service, to: name)
                onNamed(service)
            }
        } catch {
            onFailure(error.localizedDescription)
        }
    }
}

/// The sheet itself: one name field, saved or abandoned. A sheet rather than an alert
/// because an alert holds a text field and nothing else, and this is where a search for a
/// Logo will go (#29).
struct StreamingServiceNamingSheet: View {
    let naming: ServiceNaming

    /// Called with the typed name when the user saves. Whoever presents the sheet is what
    /// takes it down afterwards, because the binding that holds it up is theirs.
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String

    init(naming: ServiceNaming, onSave: @escaping (String) -> Void) {
        self.naming = naming
        self.onSave = onSave
        _name = State(initialValue: naming.currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle(naming.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Enabled whatever is typed: every rule about a name is `Library`'s,
                    // and what it refuses is said back to the user in words.
                    Button("Save") { onSave(name) }
                }
            }
        }
    }
}

#Preview("Adding") {
    StreamingServiceNamingSheet(naming: .adding) { _ in }
}

#Preview("Renaming") {
    StreamingServiceNamingSheet(naming: .renaming(StreamingService(name: "Netflix"))) { _ in }
}
