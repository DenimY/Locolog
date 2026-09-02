import SwiftUI

/// 사이드바 선택 상태
enum SidebarItem: Hashable {
    case today
    case nearby
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
    case today, nearby, calendar, map, allNotes, favorites

    static let defaultOrder = "today,nearby,calendar,map,allNotes,favorites"
    private static let legacyDefault = "calendar,map,allNotes,favorites"

    static func resolvedOrderString() -> String {
        let key = "navOrder"
        let stored = UserDefaults.standard.string(forKey: key)
        if stored == nil || stored == legacyDefault {
            UserDefaults.standard.set(defaultOrder, forKey: key)
            return defaultOrder
        }
        return stored!
    }

    var sidebarItem: SidebarItem {
        switch self {
        case .today:     return .today
        case .nearby:    return .nearby
        case .calendar:  return .calendar
        case .map:       return .map
        case .allNotes:  return .allNotes
        case .favorites: return .favorites
        }
    }

    var title: String {
        switch self {
        case .today:     return "오늘"
        case .nearby:    return "여기 근처"
        case .calendar:  return "캘린더"
        case .map:       return "지도로 보기"
        case .allNotes:  return "모든 메모"
        case .favorites: return "즐겨찾기"
        }
    }

    var icon: String {
        switch self {
        case .today:     return "sun.max"
        case .nearby:    return "location.circle"
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
    @State private var selectedTab = 0
    @ObservedObject private var deepLink = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NoteListView()
                .tabItem { Label("메모", systemImage: "note.text") }
                .tag(0)
            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
                .tag(1)
            NoteMapView()
                .tabItem { Label("지도", systemImage: "map") }
                .tag(2)
            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }
                .tag(3)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(4)
        }
        .onChange(of: deepLink.pending) { _, pending in
            if pending?.shouldShowNotesTab == true {
                selectedTab = 0
            }
        }
    }
}

// MARK: - macOS: 3-패널

#if os(macOS)
struct MainSplitView: View {
    @State private var selectedItem: SidebarItem = {
        let stored = NavItem.resolvedOrderString()
        let first = stored.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "today"
        return NavItem(rawValue: first)?.sidebarItem ?? .today
    }()
    @State private var selectedNote: Note? = nil
    @ObservedObject private var deepLink = DeepLinkRouter.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedItem)
        } content: {
            contentPanel
        } detail: {
            detailPanel
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: deepLink.pending) { _, pending in
            guard pending?.shouldShowNotesTab == true else { return }
            if selectedItem != .today && selectedItem != .nearby && selectedItem != .allNotes {
                selectedItem = .today
            }
        }
    }

    // MARK: 중앙 패널

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedItem {
        case .calendar:
            MapCalendarView(selectedNote: $selectedNote)
        case .map:
            NoteMapView(selectedNote: $selectedNote)
        case .allNotes, .favorites, .smartFolder, .tag, .folder, .today, .nearby:
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
            Text("왼쪽에서 고르거나, 새 메모를 던지세요.\n장소가 목차가 됩니다.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
