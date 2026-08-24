import SwiftUI

/// Hand-enters a Tracked Movie. Like the series form it only gathers values; every rule
/// lives in `Library`, and whatever it refuses is shown back to the user verbatim.
/// A movie starts unwatched — that is what a watchlist entry is.
struct AddTrackedMovieView: View {
    let library: Library

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var streamingService = ""
    @State private var failureMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Where") {
                    TextField("Streaming service", text: $streamingService)
                }
            }
            .navigationTitle("Track a Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                }
            }
            .alert(
                "Couldn't add the movie",
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

    private func add() {
        do {
            try library.addTrackedMovie(
                title: title,
                summary: summary,
                streamingService: streamingService
            )
            dismiss()
        } catch {
            failureMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddTrackedMovieView(library: try! Library.inMemory())
}
