import SwiftUI
import SwiftData

struct NoteListView: View {
    // macOS: SidebarView로부터 주입 / iOS: 기본값 사용
    var selectedItem: SidebarItem = .allNotes
    @Binding var selectedNote: Note?

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]

    @State private var searchText = ""
    @State private var sortOrder: NoteSortOrder = .updatedAt

    // 생성/편집 공용 — nil이면 새로 만들기, non-nil이면 편집
    @State private var editingCategory: Category? = nil
    @State private var editingSmartFolder: SmartFolder? = nil
    @State private var showCategoryForm = false
    @State private var showSmartFolderForm = false

    // iOS 전용
    #if os(iOS)
    @State private var navigationPath: [Note] = []
    @State private var filterMode: IOSFilterMode = .categories
    @State private var iOSSelectedCategoryId: UUID? = nil
    @State private var iOSSelectedSmartFolderId: UUID? = nil
    @State private var iOSSelectedTag: String? = nil

    private var usedTagNames: [String] {
        let names = allNotes.filter { !$0.isDeleted }.flatMap { $0.parsedTagNames }
        return Array(Set(names)).sorted()
    }
    #endif

    // MARK: - 필터링

    private var filteredNotes: [Note] {
        var result = allNotes.filter { !$0.isDeleted }

        #if os(iOS)
        switch filterMode {
        case .categories:
            if let catId = iOSSelectedCategoryId {
                result = result.filter { $0.categoryId == catId }
            }
        case .smartFolders:
            if let sfId = iOSSelectedSmartFolderId,
               let sf = smartFolders.first(where: { $0.id == sfId }) {
                result = applySmartFolderFilter(sf.filter, to: result)
            }
        case .tags:
            if let tag = iOSSelectedTag {
                result = result.filter { $0.parsedTagNames.contains(tag) }
            }
        }
        #else
        switch selectedItem {
        case .allNotes, .calendar, .map, .trash:
            break
        case .favorites:
            result = result.filter { $0.isFavorited }
        case .category(let cat):
            result = result.filter { $0.categoryId == cat.id }
        case .smartFolder(let sf):
            result = applySmartFolderFilter(sf.filter, to: result)
        case .tag(let tagName):
            result = result.filter { $0.parsedTagNames.contains(tagName) }
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
        case .updatedAt: result.sort { $0.updatedAt > $1.updatedAt }
        case .createdAt: result.sort { $0.createdAt > $1.createdAt }
        case .title:     result.sort { $0.displayTitle.localizedCompare($1.displayTitle) == .orderedAscending }
        }
        return result
    }

    private func applySmartFolderFilter(_ f: NoteFilter, to notes: [Note]) -> [Note] {
        var result = notes
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
                f.tagNames.allSatisfy { note.parsedTagNames.contains($0) }
            }
        }
        if f.hasLocation == true {
            result = result.filter { $0.locationName != nil || $0.locationPOI != nil }
        }
        if let from = f.dateFrom {
            result = result.filter { $0.createdAt >= from }
        }
        if let to = f.dateTo {
            let end = Calendar.current.date(byAdding: .day, value: 1,
                                            to: Calendar.current.startOfDay(for: to)) ?? to
            result = result.filter { $0.createdAt < end }
        }
        return result
    }

    private func category(for note: Note) -> Category? {
        guard let catId = note.categoryId else { return nil }
        return categories.first { $0.id == catId }
    }

    private var navigationTitle: String {
        #if os(iOS)
        switch filterMode {
        case .categories:
            if let id = iOSSelectedCategoryId,
               let cat = categories.first(where: { $0.id == id }) { return cat.name }
            return "전체 메모"
        case .smartFolders:
            if let id = iOSSelectedSmartFolderId,
               let sf = smartFolders.first(where: { $0.id == id }) { return sf.name }
            return "스마트 폴더"
        case .tags:
            if let tag = iOSSelectedTag { return "#\(tag)" }
            return "태그"
        }
        #else
        switch selectedItem {
        case .allNotes:           return "전체 메모"
        case .calendar:           return "캘린더"
        case .map:                return "지도"
        case .favorites:          return "즐겨찾기"
        case .trash:              return "휴지통"
        case .category(let cat):   return cat.name
        case .smartFolder(let sf): return sf.name
        case .tag(let tagName):    return "#\(tagName)"
        }
        #endif
    }

    // MARK: - Body

    var body: some View {
        #if os(iOS)
        NavigationStack(path: $navigationPath) {
            noteContent
                .navigationDestination(for: Note.self) { NoteEditorView(note: $0) }
                .navigationTitle(LocalizedStringKey(navigationTitle))
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, prompt: "메모, 장소 검색")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("정렬", selection: $sortOrder) {
                                ForEach(NoteSortOrder.allCases) { Text($0.rawValue).tag($0) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                editingCategory = nil
                                showCategoryForm = true
                            } label: {
                                Label("카테고리 추가", systemImage: "folder.badge.plus")
                            }
                            Button {
                                editingSmartFolder = nil
                                showSmartFolderForm = true
                            } label: {
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
                .sheet(isPresented: $showCategoryForm) {
                    CategoryFormView(editing: editingCategory)
                }
                .sheet(isPresented: $showSmartFolderForm) {
                    SmartFolderFormView(editing: editingSmartFolder)
                }
                .onChange(of: filterMode) { _, _ in
                    iOSSelectedCategoryId   = nil
                    iOSSelectedSmartFolderId = nil
                    iOSSelectedTag          = nil
                }
        }
        #else
        noteContent
            .navigationTitle(LocalizedStringKey(navigationTitle))
            .searchable(text: $searchText, prompt: "메모, 장소 검색")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNote) { Image(systemName: "square.and.pencil") }
                }
                ToolbarItem(placement: .automatic) {
                    Picker("정렬", selection: $sortOrder) {
                        ForEach(NoteSortOrder.allCases) { Text($0.rawValue).tag($0) }
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
            filterBar
            Divider()
            if filteredNotes.isEmpty { emptyState } else { iosList }
        }
        #else
        if filteredNotes.isEmpty { emptyState } else { macOSList }
        #endif
    }

    // MARK: - iOS: 필터 바 (세그먼트 + 칩)

    #if os(iOS)
    private var filterBar: some View {
        VStack(spacing: 0) {
            Picker("필터", selection: $filterMode) {
                ForEach(IOSFilterMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.label)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    switch filterMode {
                    case .categories:    categoryChips
                    case .smartFolders:  smartFolderChips
                    case .tags:          tagChips
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var categoryChips: some View {
        FilterChip(title: "전체", color: .secondary, isSelected: iOSSelectedCategoryId == nil) {
            iOSSelectedCategoryId = nil
        }
        ForEach(categories) { cat in
            FilterChip(title: cat.name, color: cat.color, isSelected: iOSSelectedCategoryId == cat.id) {
                iOSSelectedCategoryId = iOSSelectedCategoryId == cat.id ? nil : cat.id
            }
            .contextMenu {
                Button { editingCategory = cat; showCategoryForm = true } label: {
                    Label("편집", systemImage: "pencil")
                }
                Button(role: .destructive) { deleteCategory(cat) } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var smartFolderChips: some View {
        if smartFolders.isEmpty {
            Text("스마트 폴더가 없습니다")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        } else {
            FilterChip(title: "전체", color: .secondary, isSelected: iOSSelectedSmartFolderId == nil) {
                iOSSelectedSmartFolderId = nil
            }
            ForEach(smartFolders) { sf in
                FilterChip(
                    title: sf.name,
                    color: Color.accentColor,
                    icon: "folder.badge.gearshape",
                    isSelected: iOSSelectedSmartFolderId == sf.id
                ) {
                    iOSSelectedSmartFolderId = iOSSelectedSmartFolderId == sf.id ? nil : sf.id
                }
                .contextMenu {
                    Button { editingSmartFolder = sf; showSmartFolderForm = true } label: {
                        Label("편집", systemImage: "pencil")
                    }
                    Button(role: .destructive) { deleteSmartFolder(sf) } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        if usedTagNames.isEmpty {
            Text("사용된 태그가 없습니다")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        } else {
            FilterChip(title: "전체", color: .secondary, isSelected: iOSSelectedTag == nil) {
                iOSSelectedTag = nil
            }
            ForEach(usedTagNames, id: \.self) { tag in
                FilterChip(
                    title: "#\(tag)",
                    color: .purple,
                    icon: "tag.fill",
                    isSelected: iOSSelectedTag == tag
                ) {
                    iOSSelectedTag = iOSSelectedTag == tag ? nil : tag
                }
            }
        }
    }

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
    #endif

    // MARK: - macOS 목록

    #if !os(iOS)
    private var macOSList: some View {
        List(filteredNotes, selection: $selectedNote) { note in
            NoteRowView(note: note, category: category(for: note))
                .tag(note)
                .contextMenu {
                    Button {
                        createNote()
                    } label: {
                        Label("새 메모", systemImage: "square.and.pencil")
                    }
                    Divider()
                    Button {
                        note.isFavorited.toggle()
                        note.isDirty = true
                        try? context.save()
                    } label: {
                        Label(
                            note.isFavorited ? "즐겨찾기 해제" : "즐겨찾기 추가",
                            systemImage: note.isFavorited ? "star.slash" : "star"
                        )
                    }
                    Menu("노트 타입 변경") {
                        ForEach(NoteType.allCases, id: \.rawValue) { type in
                            Button {
                                note.noteType = type
                                note.isDirty = true
                                try? context.save()
                            } label: {
                                Label(LocalizedStringKey(type.label), systemImage: type.icon)
                            }
                            .disabled(note.noteType == type)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        deleteNote(note)
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
        }
        .listStyle(.plain)
        .contextMenu {
            Button {
                createNote()
            } label: {
                Label("새 메모", systemImage: "square.and.pencil")
            }
        }
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
                Button("새 메모", action: createNote).buttonStyle(.borderedProminent)
            }
        }
        #if !os(iOS)
        .contextMenu {
            Button {
                createNote()
            } label: {
                Label("새 메모", systemImage: "square.and.pencil")
            }
        }
        #endif
    }

    // MARK: - 액션

    private func createNote() {
        let categoryId: UUID?
        #if os(iOS)
        categoryId = filterMode == .categories ? iOSSelectedCategoryId : nil
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
        note.isDirty   = true
        try? context.save()
        #if !os(iOS)
        if selectedNote?.id == note.id { selectedNote = nil }
        #endif
    }

    #if os(iOS)
    private func deleteCategory(_ category: Category) {
        if iOSSelectedCategoryId == category.id { iOSSelectedCategoryId = nil }
        context.delete(category)
        try? context.save()
    }

    private func deleteSmartFolder(_ sf: SmartFolder) {
        if iOSSelectedSmartFolderId == sf.id { iOSSelectedSmartFolderId = nil }
        context.delete(sf)
        try? context.save()
    }
    #endif
}

// MARK: - 정렬 옵션

enum NoteSortOrder: String, CaseIterable, Identifiable {
    case updatedAt = "수정일"
    case createdAt = "생성일"
    case title     = "가나다"
    var id: String { rawValue }
}

// MARK: - iOS 전용

extension NoteListView {
    /// iOS TabView에서 selectedNote 없이 사용
    init() { self._selectedNote = .constant(nil) }
}

#if os(iOS)

// MARK: - iOS 필터 모드

private enum IOSFilterMode: String, CaseIterable, Identifiable {
    case categories  = "categories"
    case smartFolders = "smartFolders"
    case tags        = "tags"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .categories:   return "카테고리"
        case .smartFolders: return "스마트폴더"
        case .tags:         return "태그"
        }
    }
}

// MARK: - 필터 칩

private struct FilterChip: View {
    let title: String
    let color: Color
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.caption2)
                }
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? color : Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }
}

#endif
