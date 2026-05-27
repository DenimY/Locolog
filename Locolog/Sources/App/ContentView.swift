import SwiftUI

/// 사이드바 선택 상태 — 전체 메모 / 캘린더 / 카테고리 / 스마트 폴더
enum SidebarItem: Hashable {
    case allNotes
    case calendar
    case category(Category)
    case smartFolder(SmartFolder)
}

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

// MARK: - macOS: 3-패널 NavigationSplitView
#if os(macOS)
struct MainSplitView: View {
    @State private var selectedItem: SidebarItem = .allNotes
    @State private var selectedNote: Note? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } content: {
            if case .calendar = selectedItem {
                CalendarView(selectedNote: $selectedNote)
            } else {
                NoteListView(selectedItem: selectedItem, selectedNote: $selectedNote)
            }
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
#endif
