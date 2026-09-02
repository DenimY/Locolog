import Foundation
import SwiftUI

enum DeepLink: Equatable {
    case newNote
    case openNote(UUID)
    case open

    var shouldShowNotesTab: Bool {
        switch self {
        case .newNote, .openNote: return true
        case .open: return false
        }
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var pending: DeepLink?

    func handle(_ url: URL) {
        guard url.scheme == "locolog" || url.scheme == "com.locolog.app" else { return }

        let host = (url.host ?? "").lowercased()
        let pathID = url.path
            .split(separator: "/")
            .map(String.init)
            .first

        switch host {
        case "new":
            pending = .newNote
        case "note":
            if let pathID, let id = UUID(uuidString: pathID) {
                pending = .openNote(id)
            }
        default:
            if host.isEmpty, url.lastPathComponent.lowercased() == "new" {
                pending = .newNote
            } else {
                pending = .open
            }
        }
    }

    func consume() {
        pending = nil
    }
}
