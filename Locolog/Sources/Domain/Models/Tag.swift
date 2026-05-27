import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .nullify, inverse: \Note.tags) var notes: [Note]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.notes = []
    }
}
