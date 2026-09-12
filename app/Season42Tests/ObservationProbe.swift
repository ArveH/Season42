import Foundation

/// Whether something a test read under `withObservationTracking` was reported as changed —
/// the question a SwiftUI view's redraw turns on, asked by a test that has no view.
///
/// A box rather than a captured local `var` because the change handler is `@Sendable`.
/// Unchecked because the handler runs synchronously, on the thread that made the change,
/// which in these tests is the main actor the Library is already on.
final class ObservationProbe: @unchecked Sendable {
    private(set) var wasTold = false

    func tell() {
        wasTold = true
    }
}
