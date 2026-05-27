import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        MainTabView()
        #else
        MainSplitView()
        #endif
    }
}

// MARK: - iPhone: Tab Bar
struct MainTabView: View {
    var body: some View {
        TabView {
            NoteListView()
                .tabItem { Label("메모", systemImage: "note.text") }

            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }

            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

// MARK: - macOS: NavigationSplitView
struct MainSplitView: View {
    @State private var selectedCategory: Category? = nil
    @State private var selectedNote: Note? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
        } content: {
            NoteListView(selectedCategory: selectedCategory, selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
            } else {
                EmptyEditorView()
            }
        }
    }
}

struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("메모를 선택하거나 새 메모를 작성하세요")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
