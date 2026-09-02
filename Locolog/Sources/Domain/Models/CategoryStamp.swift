import Foundation
import SwiftData

/// 글자를 치지 않고 한 손가락으로 붙이는 2차 분류.
/// 1차 분류는 장소(회사·마트·집)이고, 스탬프는 그 안에서 더 나눌 때만 쓴다.
enum CategoryStampPreset: String, CaseIterable, Identifiable {
    case meeting
    case code
    case shopping
    case home
    case idea

    var id: String { rawValue }

    var name: String {
        switch self {
        case .meeting:  return "회의"
        case .code:     return "코드"
        case .shopping: return "장보기"
        case .home:     return "집"
        case .idea:     return "아이디어"
        }
    }

    var emoji: String {
        switch self {
        case .meeting:  return "📋"
        case .code:     return "💻"
        case .shopping: return "🛒"
        case .home:     return "🏠"
        case .idea:     return "💡"
        }
    }

    var colorHex: String {
        switch self {
        case .meeting:  return "#4A90E2"
        case .code:     return "#636366"
        case .shopping: return "#FF9500"
        case .home:     return "#34C759"
        case .idea:     return "#FFCC00"
        }
    }

    func matchingFolder(in folders: [Folder]) -> Folder? {
        let roots = folders.filter { $0.parentId == nil }
        if let byEmoji = roots.first(where: { $0.iconEmoji == emoji }) {
            return byEmoji
        }
        return roots.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

enum CategoryStampAssigner {
    /// 프리셋 또는 기존 폴더를 메모에 붙인다. 같은 것을 다시 탭하면 뗀다.
    @MainActor
    static func apply(
        preset: CategoryStampPreset? = nil,
        folder: Folder? = nil,
        to note: Note,
        folders: [Folder],
        context: ModelContext,
        toggleIfSame: Bool
    ) {
        let target: Folder?
        if let folder {
            target = folder
        } else if let preset {
            if let existing = preset.matchingFolder(in: folders) {
                target = existing
            } else {
                let nextPosition = (folders.filter { $0.parentId == nil }.map(\.position).max() ?? -1) + 1
                let created = Folder(
                    name: preset.name,
                    position: nextPosition,
                    colorHex: preset.colorHex,
                    iconEmoji: preset.emoji
                )
                context.insert(created)
                target = created
            }
        } else {
            target = nil
        }

        guard let target else { return }

        if toggleIfSame, note.folderId == target.id {
            note.folderId = nil
        } else {
            note.folderId = target.id
        }
        note.saveDirty(in: context)
    }
}
