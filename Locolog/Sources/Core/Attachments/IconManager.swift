import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// 노트/폴더 제목 앞에 붙는 커스텀 이미지 아이콘 저장소
struct IconManager {

    /// JPEG로 압축 후 Documents/NoteIcons/{ownerId}.jpg 에 저장(있으면 덮어씀), 로컬 파일 URL 반환
    static func saveIcon(_ data: Data, for ownerId: UUID) throws -> String {
        let compressed = compressedJPEG(data) ?? data
        let dir = try baseDirectory()
        let fileURL = dir.appendingPathComponent("\(ownerId.uuidString).jpg")
        try compressed.write(to: fileURL)
        return fileURL.absoluteString
    }

    static func deleteIcon(urlString: String?) {
        guard let urlString, let url = URL(string: urlString), url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func baseDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("NoteIcons")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func compressedJPEG(_ data: Data) -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image, maxDimension: 256)
        return resized.jpegData(compressionQuality: 0.85)
        #else
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bmp = NSBitmapImageRep(cgImage: cgImage)
        return bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        #endif
    }

    #if os(iOS)
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        guard scale < 1 else { return image }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    #endif
}
