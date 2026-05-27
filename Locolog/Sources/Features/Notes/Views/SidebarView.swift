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

    var body: some View {
        List(selection: $selectedItem) {
            Label("전체 메모", systemImage: "tray.full")
                .tag(SidebarItem.allNotes)

            Label("캘린더", systemImage: "calendar")
                .tag(SidebarItem.calendar)

            Section {
                ForEach(categories) { category in
                    Label {
                        Text(category.name)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(category.color)
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
            } header: {
                HStack {
                    Text("카테고리")
                    Spacer()
                    Button {
                        editingCategory = nil
                        showCategoryForm = true
                    } label: {
                        Image(systemName: "plus").font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

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
        .navigationTitle("Locolog")
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
        .sheet(isPresented: $showCategoryForm) {
            CategoryFormView(editing: editingCategory)
        }
        .sheet(isPresented: $showSmartFolderForm) {
            SmartFolderFormView(editing: editingSmartFolder)
        }
    }

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
