import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var content: String             // Markdown 원문
    var categoryId: UUID?
    var createdAt: Date             // 불변 — 최초 생성 시각
    var updatedAt: Date
    var locationLat: Double?
    var locationLng: Double?
    var locationName: String?       // 예: "서울 성동구"
    var locationPOI: String?        // 예: "성수역 3번 출구"
    var reminderAt: Date?
    var reminderLocationLat: Double?
    var reminderLocationLng: Double?
    var isDeleted: Bool
    var isDirty: Bool               // 오프라인 수정 → 동기화 대기 여부
    var attachmentURLs: [String]    // 로컬 파일 URL (Documents/NoteAttachments/)
    @Relationship(deleteRule: .nullify) var tags: [Tag]

    init(content: String = "", categoryId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.categoryId = categoryId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDeleted = false
        self.isDirty = true
        self.attachmentURLs = []
        self.tags = []
    }

    /// 목록에 표시할 제목: 첫 번째 줄, 없으면 날짜
    var displayTitle: String {
        let firstLine = content
            .components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces) ?? ""

        if firstLine.isEmpty {
            return createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        return firstLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
    }

    /// 목록에 표시할 미리보기: 첫 줄 이후 첫 번째 내용 줄
    var displayPreview: String {
        let lines = content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return "" }
        return String(lines[1].prefix(80))
    }

    /// 위치 표시 문자열
    var displayLocation: String? {
        if let poi = locationPOI, !poi.isEmpty { return poi }
        return locationName
    }

    /// content에서 #태그 파싱 (마크다운 헤더 제외, 중복 제거, 소문자)
    var parsedTagNames: [String] {
        guard let regex = Note.tagRegex else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        var seen = Set<String>()
        return regex.matches(in: content, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: content) else { return nil }
            let name = String(content[r]).lowercased()
            return seen.insert(name).inserted ? name : nil
        }
    }

    // 단어 경계 뒤에 오는 #태그만 인식 (abc#tag 같은 경우 제외)
    private static let tagRegex = try? NSRegularExpression(
        pattern: #"(?<![가-힣a-zA-Z0-9_#])#([가-힣a-zA-Z0-9_]+)"#
    )
}
