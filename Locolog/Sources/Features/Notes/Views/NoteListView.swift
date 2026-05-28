import SwiftUI
import SwiftData

struct NoteListView: View {
    // macOS: SidebarView로부터 주입 / iOS: 기본값 사용
    var selectedItem: SidebarItem = .allNotes
    @Binding var selectedNote: Note?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Category.position) private var categories: [Category]

    @State private var searchText = ""
    @State private var showCategoryForm = false
    @State private var showSmartFolderForm = false
    @State private var sortOrder: NoteSortOrder = .updatedAt
    // iOS 카테고리 칩 선택 상태
    @State private var iOSSelectedCategoryId: UUID? = nil

    #if os(iOS)
    @State private var navigationPath: [Note] = []
    #endif

    // MARK: - 필터링

    private var filteredNotes: [Note] {
        var result = allNotes.filter { !$0.isDeleted }

        #if os(iOS)
        if let catId = iOSSelectedCategoryId {
            result = result.filter { $0.categoryId == catId }
        }
        #else
        switch selectedItem {
        case .allNotes, .calendar:
            break
        case .category(let cat):
            result = result.filter { $0.categoryId == cat.id }
        case .smartFolder(let sf):
            let f = sf.filter
            if let catId = f.categoryId {
                result = result.filter { $0.categoryId == catId }
            }
            if let loc = f.locationName, !loc.isEmpty {
                result = result.filter {
                    $0.locationName?.localizedCaseInsensitiveContains(loc) ?? false ||
                    $0.locationPOI?.localizedCaseInsensitiveContains(loc) ?? false
                }
            }
            if !f.tagNames.isEmpty {
                result = result.filter { note in
                    f.tagNames.allSatisfy {
                        note.content.localizedCaseInsensitiveContains("#\($0)")
                    }
                }
            }
            if f.hasLocation == true {
                result = result.filter { $0.locationName != nil || $0.locationPOI != nil }
            }
            if let from = f.dateFrom {
                result = result.filter { $0.createdAt >= from }
            }
            if let to = f.dateTo {
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: to)) ?? to
                result = result.filter { $0.createdAt < endOfDay }
            }
        }
        #endif

        if !searchText.isEmpty {
            let q = searchText
            result = result.filter {
                $0.content.localizedCaseInsensitiveContains(q) ||
                ($0.locationName?.localizedCaseInsensitiveContains(q) ?? false) ||
                ($0.locationPOI?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }

        switch sortOrder {
        case .updatedAt:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .createdAt:
            result.sort { $0.createdAt > $1.createdAt }
        case .title:
            result.sort { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        }
        return result
    }

    private func category(for note: Note) -> Category? {
        guard let catId = note.categoryId else { return nil }
        return categories.first { $0.id == catId }
    }

    private var navigationTitle: String {
        #if os(iOS)
        if let catId = iOSSelectedCategoryId,
           let cat = categories.first(where: { $0.id == catId }) {
            return cat.name
        }
        return "전체 메모"
        #else
        switch selectedItem {
        case .allNotes: return "전체 메모"
        case .calendar: return "캘린더"
        case .category(let cat): return cat.name
        case .smartFolder(let sf): return sf.name
        }
        #endif
    }

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        NavigationStack(path: $navigationPath) {
            noteContent
                .navigationDestination(for: Note.self) { NoteEditorView(note: $0) }
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "메모, 장소 검색")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("정렬", selection: $sortOrder) {
                                ForEach(NoteSortOrder.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { showCategoryForm = true } label: {
                                Label("카테고리 추가", systemImage: "folder.badge.plus")
                            }
                            Button { showSmartFolderForm = true } label: {
                                Label("스마트 폴더 추가", systemImage: "folder.badge.gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: createNote) {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .sheet(isPresented: $showCategoryForm) { CategoryFormView() }
                .sheet(isPresented: $showSmartFolderForm) { SmartFolderFormView() }
        }
        #else
        noteContent
            .navigationTitle(navigationTitle)
            .searchable(text: $searchText, prompt: "메모, 장소 검색")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNote) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Picker("정렬", selection: $sortOrder) {
                        ForEach(NoteSortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        #endif
    }

    // MARK: - 컨텐츠

    @ViewBuilder
    private var noteContent: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            if !categories.isEmpty {
                categoryChipBar
                Divider()
            }
            if filteredNotes.isEmpty {
                emptyState
            } else {
                iosList
            }
        }
        #else
        if filteredNotes.isEmpty {
            emptyState
        } else {
            macOSList
        }
        #endif
    }

    // MARK: - iOS 전용

    #if os(iOS)
    private var iosList: some View {
        List(filteredNotes) { note in
            NavigationLink(value: note) {
                NoteRowView(note: note, category: category(for: note))
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { deleteNote(note) } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
    }

    private var categoryChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "전체",
                    color: .secondary,
                    isSelected: iOSSelectedCategoryId == nil
                ) {
                    iOSSelectedCategoryId = nil
                }
                ForEach(categories) { cat in
                    CategoryChip(
                        title: cat.name,
                        color: cat.color,
                        isSelected: iOSSelectedCategoryId == cat.id
                    ) {
                        iOSSelectedCategoryId = iOSSelectedCategoryId == cat.id ? nil : cat.id
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }
    #endif

    // MARK: - macOS 전용

    #if !os(iOS)
    private var macOSList: some View {
        List(filteredNotes, selection: $selectedNote) { note in
            NoteRowView(note: note, category: category(for: note))
                .tag(note)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleteNote(note) } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
        .listStyle(.plain)
    }
    #endif

    // MARK: - 빈 상태

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

    // MARK: - 액션

    private func createNote() {
        let categoryId: UUID?
        #if os(iOS)
        categoryId = iOSSelectedCategoryId
        #else
        if case .category(let cat) = selectedItem { categoryId = cat.id }
        else { categoryId = nil }
        #endif

        let note = Note(categoryId: categoryId)
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

// MARK: - 정렬 옵션

enum NoteSortOrder: String, CaseIterable, Identifiable {
    case updatedAt = "수정일"
    case createdAt = "생성일"
    case title = "가나다"

    var id: String { rawValue }
}

// MARK: - iOS TabView에서 selectedNote 없이 사용
extension NoteListView {
    init() {
        self._selectedNote = .constant(nil)
    }
}

// MARK: - iOS 카테고리 칩

#if os(iOS)
private struct CategoryChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? color : Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }
}
#endif
