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
