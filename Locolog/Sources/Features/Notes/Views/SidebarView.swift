#if os(macOS)
import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var context

    @AppStorage("navOrder") private var navOrderString: String = "calendar,map,allNotes,favorites"

    @State private var showCategoryForm = false
    @State private var showSmartFolderForm = false
    @State private var editingCategory: Category?
    @State private var editingSmartFolder: SmartFolder?
    @State private var showSettings = false

    // AppStorage 문자열을 [NavItem]으로 변환
    private var navItems: [NavItem] {
        var parsed = navOrderString.split(separator: ",")
            .compactMap { NavItem(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
        for item in NavItem.allCases where !parsed.contains(item) {
            parsed.append(item)
        }
        return parsed
    }

    // 삭제되지 않은 메모가 있는 태그만 표시
    private var usedTags: [Tag] {
        allTags.filter { tag in tag.notes.contains { !$0.isDeleted } }
    }

    var body: some View {
        List(selection: Binding<SidebarItem?>(
            get: { selectedItem },
            set: { selectedItem = $0 ?? .allNotes }
        )) {

            // MARK: - 상단 고정 항목 (드래그 정렬 가능)

            Section {
                ForEach(navItems, id: \.rawValue) { item in
                    Label(item.title, systemImage: item.icon)
                        .foregroundStyle(
                            item == .favorites && selectedItem != .favorites
                                ? Color.yellow : Color.primary
                        )
                        .tag(item.sidebarItem)
                }
                .onMove { from, to in
                    var items = navItems
                    items.move(fromOffsets: from, toOffset: to)
                    navOrderString = items.map { $0.rawValue }.joined(separator: ",")
                }
            }

            // MARK: - 카테고리 (드래그 정렬 가능)

            Section {
                ForEach(categories) { category in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                    }
                    .tag(SidebarItem.category(category))
                    .contextMenu {
                        Button {
                            editingCategory = category
                            showCategoryForm = true
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteCategory(category)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    var items = categories
                    items.move(fromOffsets: from, toOffset: to)
                    for (idx, cat) in items.enumerated() {
                        cat.position = idx
                    }
                    try? context.save()
                }

                Button {
                    editingCategory = nil
                    showCategoryForm = true
                } label: {
                    Label("카테고리 추가", systemImage: "plus")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
            } header: {
                Text("카테고리")
            }

            // MARK: - 태그

            if !usedTags.isEmpty {
                Section {
                    ForEach(usedTags, id: \.name) { tag in
                        Label("#\(tag.name)", systemImage: "tag.fill")
                            .foregroundStyle(
                                selectedItem == .tag(tag.name) ? Color.primary : Color.purple
                            )
                            .tag(SidebarItem.tag(tag.name))
                    }
                } header: {
                    Text("태그")
                }
            }

            // MARK: - 스마트 폴더

            if !smartFolders.isEmpty {
                Section {
                    ForEach(smartFolders) { folder in
                        Label(folder.name, systemImage: "folder.badge.gearshape")
                            .tag(SidebarItem.smartFolder(folder))
                            .contextMenu {
                                Button {
                                    editingSmartFolder = folder
                                    showSmartFolderForm = true
                                } label: {
                                    Label("편집", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    deleteSmartFolder(folder)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("스마트 폴더")
                        Spacer()
                        Button {
                            editingSmartFolder = nil
                            showSmartFolderForm = true
                        } label: {
                            Image(systemName: "plus").font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Locolog")
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showCategoryForm) {
            CategoryFormView(editing: editingCategory)
        }
        .sheet(isPresented: $showSmartFolderForm) {
            SmartFolderFormView(editing: editingSmartFolder)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(minWidth: 480, minHeight: 400)
        }
    }

    // MARK: - 하단 바

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button {
                    showSettings = true
                } label: {
                    Label("설정", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("설정")

                Spacer()

                Button {
                    selectedItem = .trash
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(selectedItem == .trash ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("휴지통")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    // MARK: - 액션

    private func deleteCategory(_ category: Category) {
        if case .category(let sel) = selectedItem, sel.id == category.id {
            selectedItem = .allNotes
        }
        context.delete(category)
        try? context.save()
    }

    private func deleteSmartFolder(_ folder: SmartFolder) {
        if case .smartFolder(let sel) = selectedItem, sel.id == folder.id {
            selectedItem = .allNotes
        }
        context.delete(folder)
        try? context.save()
    }
}
#endif
