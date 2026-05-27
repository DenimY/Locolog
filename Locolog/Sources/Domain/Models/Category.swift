import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var colorHex: String
    var icon: String?
    var position: Int

    init(name: String, colorHex: String = "#4A90E2", icon: String? = nil, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.position = position
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
