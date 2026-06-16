import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static var locologNote: UTType { UTType(exportedAs: "com.locolog.app.note") }
    static var locologFolder: UTType { UTType(exportedAs: "com.locolog.app.folder") }
}

/// 메모를 폴더로 드래그할 때 전달되는 데이터
struct NoteTransfer: Codable, Transferable {
    let noteId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .locologNote)
    }
}

/// 폴더를 다른 폴더로 드래그(재배치)할 때 전달되는 데이터
struct FolderTransfer: Codable, Transferable {
    let folderId: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .locologFolder)
    }
}
