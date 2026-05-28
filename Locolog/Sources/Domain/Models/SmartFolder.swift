import Foundation
import SwiftData

/// 저장된 필터 조건 — 사이드바에 카테고리와 동일 레벨로 표시
@Model
final class SmartFolder {
    var id: UUID
    var name: String
    var filterJSON: String   // NoteFilter를 JSON 직렬화한 값
    var position: Int

    init(name: String, filter: NoteFilter, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.filterJSON = (try? JSONEncoder().encode(filter)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.position = position
    }

    var filter: NoteFilter {
        guard let data = filterJSON.data(using: .utf8),
              let filter = try? JSONDecoder().decode(NoteFilter.self, from: data)
        else { return NoteFilter() }
        return filter
    }
}

/// 복합 필터 조건
struct NoteFilter: Codable {
    var categoryId: UUID?
    var tagNames: [String] = []
    var locationName: String?
    var hasLocation: Bool?
    var dateFrom: Date?
    var dateTo: Date?
}
