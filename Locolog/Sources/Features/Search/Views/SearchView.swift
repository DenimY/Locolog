import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Query private var allFolders: [Folder]
    @State private var searchText = ""
    @State private var recentSearches: [String] = []

    // MARK: - 태그 검색 감지

    /// 검색어가 #으로 시작하면 태그 검색 모드
    private var isTagSearch: Bool {
        searchText.hasPrefix("#")
    }

    private var tagQuery: String {
        String(searchText.dropFirst()).lowercased().trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 사용 중인 태그 목록

    private var allTagNames: [String] {
        let names = allNotes.filter { !$0.isDeleted }.flatMap { $0.parsedTagNames }
        return Array(Set(names)).sorted()
    }

    private var suggestedTags: [String] {
        tagQuery.isEmpty
            ? allTagNames
            : allTagNames.filter { $0.hasPrefix(tagQuery) }
    }

    // MARK: - 검색 결과

    private var results: [Note] {
        guard !searchText.isEmpty else { return [] }

        if isTagSearch {
            guard !tagQuery.isEmpty else { return [] }
            return allNotes.filter {
                !$0.isDeleted && $0.parsedTagNames.contains(where: { $0.hasPrefix(tagQuery) })
            }
        }

        let q = searchText
        return allNotes.filter { note in
            !note.isDeleted && (
                note.content.localizedCaseInsensitiveContains(q) ||
                note.locationName?.localizedCaseInsensitiveContains(q) ?? false ||
                note.locationPOI?.localizedCaseInsensitiveContains(q) ?? false ||
                note.parsedTagNames.contains { $0.localizedCaseInsensitiveContains(q) }
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    recentSearchView
                } else if isTagSearch && tagQuery.isEmpty {
                    // '#' 만 입력한 경우 → 태그 제안 목록
                    tagSuggestionView
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    resultList
                }
            }
            .navigationTitle("검색")
            .searchable(text: $searchText, prompt: "메모, 장소, #태그 검색")
            .onSubmit(of: .search) { saveRecentSearch() }
            // 태그 검색 중일 때 상단 힌트 배너
            .safeAreaInset(edge: .top) {
                if isTagSearch && !suggestedTags.isEmpty {
                    tagSuggestionBar
                }
            }
        }
    }

    // MARK: - 태그 제안 바 (검색 중 상단)

    private var tagSuggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { tag in
                    Button {
                        searchText = "#\(tag)"
                    } label: {
                        Text("#\(tag)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.purple.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    // MARK: - 태그 전체 목록 (# 입력 직후)

    private var tagSuggestionView: some View {
        List {
            Section {
                ForEach(allTagNames, id: \.self) { tag in
                    Button {
                        searchText = "#\(tag)"
                    } label: {
                        Label("#\(tag)", systemImage: "tag.fill")
                            .foregroundStyle(.purple)
                    }
                }
            } header: {
                Text("태그로 검색")
            } footer: {
                Text("태그를 선택하거나 계속 입력하세요.")
            }
        }
    }

    // MARK: - 결과 목록

    private var resultList: some View {
        List(results) { note in
            NavigationLink(value: note) {
                NoteRowView(note: note, folder: allFolders.first { $0.id == note.folderId })
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Note.self) { NoteEditorView(note: $0).id($0.id) }
        .overlay(alignment: .top) {
            if isTagSearch {
                tagSearchHeader
            }
        }
    }

    private var tagSearchHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.caption)
                .foregroundStyle(.purple)
            Text("#\(tagQuery) 태그 검색 결과 \(results.count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    // MARK: - 최근 검색

    private var recentSearchView: some View {
        List {
            if !recentSearches.isEmpty {
                Section("최근 검색") {
                    ForEach(recentSearches, id: \.self) { term in
                        Button {
                            searchText = term
                        } label: {
                            Label(term, systemImage: term.hasPrefix("#") ? "tag" : "clock")
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { recentSearches.remove(atOffsets: $0) }
                }
            }

            if !allTagNames.isEmpty {
                Section("태그 바로가기") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allTagNames.prefix(15), id: \.self) { tag in
                                Button {
                                    searchText = "#\(tag)"
                                } label: {
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color.purple.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func saveRecentSearch() {
        guard !searchText.isEmpty else { return }
        recentSearches.removeAll { $0 == searchText }
        recentSearches.insert(searchText, at: 0)
        if recentSearches.count > 10 { recentSearches.removeLast() }
    }
}
