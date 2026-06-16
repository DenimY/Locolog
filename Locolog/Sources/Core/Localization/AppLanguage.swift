import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:  return "시스템 기본"
        case .korean:  return "한국어"
        case .english: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system:  return Locale.autoupdatingCurrent
        case .korean:  return Locale(identifier: "ko")
        case .english: return Locale(identifier: "en")
        }
    }
}
