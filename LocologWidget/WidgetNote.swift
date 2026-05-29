import Foundation

/// 위젯에서 사용하는 경량 메모 모델
/// App Group UserDefaults를 통해 메인 앱 ↔ 위젯 공유
struct WidgetNote: Codable, Identifiable {
    let id: String
    let title: String
    let preview: String
    let locationName: String?
    let createdAt: Date

    static let appGroupID  = "group.com.locolog.app"
    static let storageKey  = "widget_recent_notes"

    // MARK: - 위젯에서 읽기

    static func load() -> [WidgetNote] {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data     = defaults.data(forKey: storageKey),
            let notes    = try? JSONDecoder().decode([WidgetNote].self, from: data)
        else { return [] }
        return notes
    }
}
