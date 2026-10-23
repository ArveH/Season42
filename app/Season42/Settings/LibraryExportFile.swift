import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The Library Export as something the system share/export sheet can hand on: the file is
/// written only once the user picks where it goes, not every time Settings is drawn. What
/// the file says is the Library's business (`Library.export()`); this only names it and
/// puts it somewhere the sheet can read it from.
struct LibraryExportFile: Transferable {
    let library: Library

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try await file.library.export()
            let day = Date.now.formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory
                .appending(path: "Season42 Library \(day).json")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
