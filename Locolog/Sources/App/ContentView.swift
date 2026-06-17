import SwiftUI

/// 사이드바 선택 상태
enum SidebarItem: Hashable {
    case calendar
    case map
    case allNotes
    case favorites
    case trash
    case smartFolder(SmartFolder)
    case tag(String)
    case folder(Folder)
}

/// macOS 사이드바 상단 고정 항목 (순서 저장 대상)
enum NavItem: String, CaseIterable {
    case calendar, map, allNotes, favorites

    var sidebarItem: SidebarItem {
        switch self {
        case .calendar:  return .calendar
        case .map:       return .map
        case .allNotes:  return .allNotes
        case .favorites: return .favorites
        }
    }

    var title: String {
        switch self {
        case .calendar:  return "캘린더"
        case .map:       return "지도로 보기"
        case .allNotes:  return "모든 메모"
        case .favorites: return "즐겨찾기"
        }
    }

    var icon: String {
        switch self {
        case .calendar:  return "calendar"
        case .map:       return "map"
        case .allNotes:  return "tray.full"
        case .favorites: return "star.fill"
        }
    }
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
            NoteMapView()
                .tabItem { Label("지도", systemImage: "map") }
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

// MARK: - macOS: 3-패널

#if os(macOS)
struct MainSplitView: View {
    @State private var selectedItem: SidebarItem = {
        let stored = UserDefaults.standard.string(forKey: "navOrder") ?? "calendar,map,allNotes,favorites"
        let first = stored.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "calendar"
        return NavItem(rawValue: first)?.sidebarItem ?? .calendar
    }()
    @State private var selectedNote: Note? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } content: {
            contentPanel
        } detail: {
            detailPanel
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: 중앙 패널

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedItem {
        case .calendar:
            MapCalendarView(selectedNote: $selectedNote)
        case .map:
            NoteMapView(selectedNote: $selectedNote)
        case .allNotes, .favorites, .smartFolder, .tag, .folder:
            NoteListView(selectedItem: selectedItem, selectedNote: $selectedNote)
        case .trash:
            TrashView(selectedNote: $selectedNote)
        }
    }

    // MARK: 우측 패널

    @ViewBuilder
    private var detailPanel: some View {
        if let note = selectedNote {
            NoteEditorView(note: note)
                .id(note.id)
        } else {
            EmptyDetailView()
        }
    }
}

// MARK: - 빈 상태

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("메모를 선택하세요")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("왼쪽 목록에서 메모를 선택하거나\n새 메모를 작성하세요.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
