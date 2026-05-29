import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 메인 앱 → 위젯 데이터 전달 (App Group UserDefaults)
struct WidgetDataManager {
    private static let appGroupID = "group.com.locolog.app"
    private static let storageKey = "widget_recent_notes"

    // MARK: - 데이터 쓰기 (메인 앱에서 호출)

    static func update(with notes: [Note]) {
        let widgetNotes = notes
            .filter { !$0.isDeleted }
            .prefix(5)
            .map {
                WidgetNotePayload(
                    id:           $0.id.uuidString,
                    title:        $0.displayTitle,
                    preview:      $0.displayPreview,
                    locationName: $0.displayLocation,
                    createdAt:    $0.createdAt
                )
            }

        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let data = try? JSONEncoder().encode(Array(widgetNotes)) {
            defaults.set(data, forKey: storageKey)
        }

        // 위젯 타임라인 즉시 갱신
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

/// 메인 앱 내에서 직렬화에 사용하는 경량 구조체
private struct WidgetNotePayload: Codable {
    let id: String
    let title: String
    let preview: String
    let locationName: String?
    let createdAt: Date
}
