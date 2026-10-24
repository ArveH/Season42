import SwiftUI

extension View {
    /// Tells the user an entry was saved without the Streaming Service they picked, because it
    /// was deleted on another device while the sheet was open (ADR-0024). Shown by whoever
    /// opened the sheet, once it has closed: an alert raised by the sheet itself would go
    /// down with it.
    func serviceDeletedElsewhereAlert(_ notice: Binding<ServiceDeletedElsewhere?>) -> some View {
        alert(
            "Saved without a streaming service",
            isPresented: .init(
                get: { notice.wrappedValue != nil },
                set: { if !$0 { notice.wrappedValue = nil } }
            ),
            presenting: notice.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
    }
}
