import SwiftUI

/// Picks where the user watches something, out of the Streaming Services they have
/// registered. It is the whole of what a series or movie form asks about a service — the
/// free-text field it replaces let every entry invent its own spelling.
struct StreamingServicePicker: View {
    let library: Library
    @Binding var selection: StreamingService?

    var body: some View {
        NavigationLink {
            StreamingServiceList(library: library, selection: $selection)
        } label: {
            LabeledContent("Streaming service", value: selection?.name ?? "None")
        }
    }
}

/// The list the picker pushes: none, then every registered service, then a way to
/// register one without abandoning a half-filled form.
private struct StreamingServiceList: View {
    let library: Library
    @Binding var selection: StreamingService?

    @Environment(\.dismiss) private var dismiss

    @State private var naming: ServiceNaming?
    @State private var failureMessage: String?

    var body: some View {
        List {
            Section {
                row(for: nil)
                ForEach(library.streamingServices) { service in
                    row(for: service)
                }
            }

            Section {
                Button("Add new service…", systemImage: "plus") { naming = .adding }
            }
        }
        .navigationTitle("Streaming service")
        .navigationBarTitleDisplayMode(.inline)
        .streamingServiceNamingAlert(
            naming: $naming,
            library: library,
            onFailure: { failureMessage = $0 },
            // Registering a service here is only ever in service of picking it, so it is
            // picked and the user is put back in the form they were filling.
            onNamed: { service in
                selection = service
                dismiss()
            }
        )
        .alert(
            "Couldn't add the streaming service",
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

    /// One choice, service or none, marked when it is the one in force.
    private func row(for service: StreamingService?) -> some View {
        Button {
            selection = service
            dismiss()
        } label: {
            HStack {
                Text(service?.name ?? "None")
                Spacer()
                if service == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
