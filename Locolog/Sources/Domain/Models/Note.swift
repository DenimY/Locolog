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
    @Relationship(deleteRule: .nullify) var tags: [Tag]

    init(content: String = "", categoryId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.categoryId = categoryId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDeleted = false
        self.isDirty = true
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
        // 마크다운 헤더 기호 제거 (#, ##, ###)
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
}
