import SwiftUI
import SwiftData

struct NoteListView: View {
    var selectedCategory: Category? = nil

    // macOS: NavigationSplitView 에서 주입
    @Binding var selectedNote: Note?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText = ""

    // iOS: 내부 NavigationStack 경로
    #if os(iOS)
    @State private var navigationPath: [Note] = []
    #endif

    // MARK: - Filtered

    private var filteredNotes: [Note] {
        allNotes
            .filter { !$0.isDeleted }
            .filter { selectedCategory == nil || $0.categoryId == selectedCategory?.id }
            .filter { note in
                guard !searchText.isEmpty else { return true }
                let q = searchText
                return note.content.localizedCaseInsensitiveContains(q)
                    || (note.locationName?.localizedCaseInsensitiveContains(q) ?? false)
                    || (note.locationPOI?.localizedCaseInsensitiveContains(q) ?? false)
            }
    }

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        NavigationStack(path: $navigationPath) {
            noteList
                .navigationDestination(for: Note.self) { note in
                    NoteEditorView(note: note)
                }
        }
        #else
        noteList
        #endif
    }

    // MARK: - Note List

    private var noteList: some View {
        Group {
            if filteredNotes.isEmpty {
                emptyState
            } else {
                #if os(iOS)
                List(filteredNotes) { note in
                    NavigationLink(value: note) {
                        NoteRowView(note: note)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { deleteNote(note) } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
                #else
                List(filteredNotes, selection: $selectedNote) { note in
                    NoteRowView(note: note)
                        .tag(note)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteNote(note) } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.plain)
                #endif
            }
        }
        .searchable(text: $searchText, prompt: "메모, 장소 검색")
        .navigationTitle(selectedCategory?.name ?? "전체 메모")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNote) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("메모 없음", systemImage: "note.text")
        } description: {
            Text(searchText.isEmpty
                 ? "오른쪽 위 버튼을 눌러 첫 메모를 작성하세요."
                 : "'\(searchText)' 검색 결과가 없습니다.")
        } actions: {
            if searchText.isEmpty {
                Button("새 메모", action: createNote)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Actions

    private func createNote() {
        let note = Note(categoryId: selectedCategory?.id)
        context.insert(note)
        try? context.save()

        #if os(iOS)
        navigationPath.append(note)
        #else
        selectedNote = note
        #endif
    }

    private func deleteNote(_ note: Note) {
        note.isDeleted = true
        note.isDirty = true
        try? context.save()
        #if !os(iOS)
        if selectedNote?.id == note.id { selectedNote = nil }
        #endif
    }
}

// MARK: - iOS 전용 init (TabView 에서 selectedNote 없이 사용)

extension NoteListView {
    init(selectedCategory: Category? = nil) {
        self.selectedCategory = selectedCategory
        self._selectedNote = .constant(nil)
    }
}
