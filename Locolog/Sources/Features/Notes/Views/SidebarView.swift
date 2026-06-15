#if os(macOS)
import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]
    @Environment(\.modelContext) private var context

    @State private var showCategoryForm = false
    @State private var showSmartFolderForm = false
    @State private var editingCategory: Category?
    @State private var editingSmartFolder: SmartFolder?
    @State private var showSettings = false

    var body: some View {
        List(selection: Binding<SidebarItem?>(
            get: { selectedItem },
            set: { selectedItem = $0 ?? .allNotes }
        )) {

            // MARK: - 상단 내비게이션

            Section {
                Label("캘린더", systemImage: "calendar")
                    .tag(SidebarItem.calendar)

                Label("지도로 보기", systemImage: "map")
                    .tag(SidebarItem.map)

                Label("모든 메모", systemImage: "tray.full")
                    .tag(SidebarItem.allNotes)

                Label("즐겨찾기", systemImage: "star.fill")
                    .foregroundStyle(selectedItem == .favorites ? Color.primary : Color.yellow)
                    .tag(SidebarItem.favorites)
            }

            // MARK: - 카테고리

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
                Text("캘린더")
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
        // 하단: 설정, 휴지통
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
