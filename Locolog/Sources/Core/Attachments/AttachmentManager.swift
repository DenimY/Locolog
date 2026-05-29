import Foundation
import SwiftData

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct AttachmentManager {

    // MARK: - 저장

    /// JPEG로 압축 후 Documents/NoteAttachments/{noteId}/ 에 저장, 로컬 파일 URL 반환
    static func saveImage(_ data: Data, for noteId: UUID) throws -> String {
        let compressed = compressedJPEG(data) ?? data
        let noteDir = try attachmentsDir(for: noteId)
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = noteDir.appendingPathComponent(fileName)
        try compressed.write(to: fileURL)
        return fileURL.absoluteString
    }

    // MARK: - 삭제

    static func deleteAttachment(urlString: String) {
        guard let url = URL(string: urlString), url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAll(for noteId: UUID) {
        guard let dir = try? attachmentsDir(for: noteId) else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - 읽기

    static func localURL(from urlString: String) -> URL? {
        guard let url = URL(string: urlString), url.isFileURL else { return nil }
        return url
    }

    // MARK: - Helpers

    private static func attachmentsDir(for noteId: UUID) throws -> URL {
        let base = try baseDirectory()
        let noteDir = base.appendingPathComponent(noteId.uuidString)
        try FileManager.default.createDirectory(at: noteDir, withIntermediateDirectories: true)
        return noteDir
    }

    private static func baseDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("NoteAttachments")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func compressedJPEG(_ data: Data) -> Data? {
        #if os(iOS)
        return UIImage(data: data)?.jpegData(compressionQuality: 0.8)
        #else
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bmp = NSBitmapImageRep(cgImage: cgImage)
        return bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #endif
    }
}
