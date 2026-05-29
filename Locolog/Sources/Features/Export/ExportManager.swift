import Foundation

#if os(iOS)
import UIKit
#endif

struct ExportManager {

    // MARK: - Markdown

    /// note.content를 임시 .md 파일로 저장, URL 반환
    static func markdownFileURL(for note: Note) throws -> URL {
        let safeTitle = sanitizedTitle(note.displayTitle)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle).md")
        try note.content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF (iOS)

    #if os(iOS)
    /// note.content를 A4 PDF로 렌더링, 임시 파일 URL 반환
    static func pdfFileURL(for note: Note) throws -> URL {
        let pdfData = renderPDF(note: note)
        let safeTitle = sanitizedTitle(note.displayTitle)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle).pdf")
        try pdfData.write(to: url)
        return url
    }

    private static func renderPDF(note: Note) -> Data {
        // A4: 595 × 842 pt
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 50

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { ctx in
            let contentRect = CGRect(
                x: margin, y: margin,
                width: pageRect.width - margin * 2,
                height: pageRect.height - margin * 2
            )

            // 제목 속성
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let bodyFont  = UIFont.systemFont(ofSize: 12)
            let lineSpacing: CGFloat = 4

            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.lineSpacing = lineSpacing
            titleParagraph.paragraphSpacing = 8

            let bodyParagraph = NSMutableParagraphStyle()
            bodyParagraph.lineSpacing = lineSpacing

            // 날짜 + 위치 메타
            var metaParts: [String] = [note.createdAt.formatted(date: .long, time: .shortened)]
            if let loc = note.displayLocation { metaParts.append(loc) }
            let metaText = metaParts.joined(separator: "  ·  ")

            let fullText = NSMutableAttributedString()

            // 제목
            let titleText = note.displayTitle.isEmpty ? "메모" : note.displayTitle
            fullText.append(NSAttributedString(
                string: titleText + "\n",
                attributes: [.font: titleFont, .paragraphStyle: titleParagraph]
            ))
            // 메타
            fullText.append(NSAttributedString(
                string: metaText + "\n\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: bodyParagraph
                ]
            ))
            // 본문
            fullText.append(NSAttributedString(
                string: note.content,
                attributes: [.font: bodyFont, .paragraphStyle: bodyParagraph]
            ))

            // 여러 페이지 처리
            let framesetter = CTFramesetterCreateWithAttributedString(fullText)
            var offset = 0
            var pageIndex = 0

            while offset < fullText.length {
                ctx.beginPage()
                let path = CGPath(rect: contentRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRangeMake(offset, 0),
                    path, nil
                )
                CTFrameDraw(frame, ctx.cgContext)

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                offset += visibleRange.length
                pageIndex += 1

                // 무한 루프 방지
                if pageIndex > 100 { break }
            }
        }
    }
    #endif

    // MARK: - Helpers

    private static func sanitizedTitle(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")
        let safe = title.isEmpty ? "메모" : title
        return safe.components(separatedBy: invalid).joined(separator: "_").prefix(60).description
    }
}
