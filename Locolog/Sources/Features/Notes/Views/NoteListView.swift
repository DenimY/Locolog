import SwiftUI
import SwiftData

struct NoteListView: View {
    var selectedCategory: Category? = nil
    @Binding var selectedNote: Note?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText = ""

    private var filteredNotes: [Note] {
        allNotes
            .filter { !$0.isDeleted }
            .filter { selectedCategory == nil || $0.categoryId == selectedCategory?.id }
            .filter { note in
                guard !searchText.isEmpty else { return true }
                return note.content.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        List(filteredNotes, selection: $selectedNote) { note in
            NoteRowView(note: note)
                .tag(note)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "메모 검색")
        .navigationTitle(selectedCategory?.name ?? "전체 메모")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNote) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func createNote() {
        let note = Note(categoryId: selectedCategory?.id)
        context.insert(note)
        selectedNote = note
    }
}

// iOS 전용 — selectedNote Binding 없이 사용
extension NoteListView {
    init(selectedCategory: Category? = nil) {
        self.selectedCategory = selectedCategory
        self._selectedNote = .constant(nil)
    }
}
