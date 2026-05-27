import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @State private var searchText = ""
    @State private var recentSearches: [String] = []

    private var results: [Note] {
        guard !searchText.isEmpty else { return [] }
        return allNotes.filter { note in
            !note.isDeleted && (
                note.content.localizedCaseInsensitiveContains(searchText) ||
                (note.locationName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.locationPOI?.localizedCaseInsensitiveContains(searchText) ?? false)
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    recentSearchView
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("검색")
            .searchable(text: $searchText, prompt: "메모, 장소, 태그 검색")
            .onSubmit(of: .search) { saveRecentSearch() }
        }
    }

    private var recentSearchView: some View {
        List {
            if !recentSearches.isEmpty {
                Section("최근 검색") {
                    ForEach(recentSearches, id: \.self) { term in
                        Button { searchText = term } label: {
                            Label(term, systemImage: "clock")
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { recentSearches.remove(atOffsets: $0) }
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
