import Foundation
import SwiftData
import SwiftUI

@Model
final class Folder {
    var id: UUID
    var name: String
    var parentId: UUID?
    var position: Int
    var colorHex: String?
    var iconEmoji: String?       // 폴더 이름 앞에 표시할 이모지
    var iconImagePath: String?   // 폴더 이름 앞에 표시할 커스텀 이미지 (Documents/NoteIcons/)

    init(name: String, parentId: UUID? = nil, position: Int = 0, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.parentId = parentId
        self.position = position
        self.colorHex = colorHex
    }

    var color: Color {
        colorHex.flatMap { Color(hex: $0) } ?? .accentColor
    }
}
