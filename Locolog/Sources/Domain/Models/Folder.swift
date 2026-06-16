import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var parentId: UUID?
    var position: Int

    init(name: String, parentId: UUID? = nil, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.parentId = parentId
        self.position = position
    }
}
