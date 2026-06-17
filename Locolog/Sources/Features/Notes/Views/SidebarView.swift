#if os(macOS)
import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query private var allFolders: [Folder]
    @Environment(\.modelContext) private var context

    @AppStorage("navOrder") private var navOrderString: String = "calendar,map,allNotes,favorites"

    @State private var showSmartFolderForm = false
    @State private var showFolderForm = false
    @State private var editingSmartFolder: SmartFolder?
    @State private var editingFolder: Folder?
    @State private var newFolderParentId: UUID?
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

    // 폴더 트리 (최상위)
    private var folderTree: [FolderNode] {
        buildFolderTree(parentId: nil)
    }

    private func buildFolderTree(parentId: UUID?) -> [FolderNode] {
        let children = allFolders
            .filter { $0.parentId == parentId }
            .sorted { $0.position < $1.position }
            .map { folder -> FolderNode in
                let kids = buildFolderTree(parentId: folder.id)
                return FolderNode(folder: folder, children: kids.isEmpty ? nil : kids)
            }
        return children
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

            // MARK: - 메모 폴더 (트리형, 드래그 앤 드롭)

            Section {
                OutlineGroup(folderTree, children: \.children) { node in
                    folderRow(node.folder)
                }

                Button {
                    editingFolder = nil
                    newFolderParentId = nil
                    showFolderForm = true
                } label: {
                    Label("새 폴더", systemImage: "plus")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
            } header: {
                Text("메모")
            }
            .dropDestination(for: FolderTransfer.self) { items, _ in
                guard let item = items.first else { return false }
                return reparentFolder(item.folderId, into: nil)
            }
            .dropDestination(for: NoteTransfer.self) { items, _ in
                guard let item = items.first else { return false }
                return fileNote(item.noteId, into: nil)
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
        .sheet(isPresented: $showSmartFolderForm) {
            SmartFolderFormView(editing: editingSmartFolder)
        }
        .sheet(isPresented: $showFolderForm) {
            FolderFormView(editing: editingFolder, parentId: newFolderParentId)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(minWidth: 480, minHeight: 400)
        }
    }

    // MARK: - 폴더 행

    @ViewBuilder
    private func folderRow(_ folder: Folder) -> some View {
        HStack(spacing: 8) {
            if folder.iconEmoji != nil || folder.iconImagePath != nil {
                IconView(emoji: folder.iconEmoji, imagePath: folder.iconImagePath, fallbackSymbol: "folder", size: 16)
            } else {
                Image(systemName: "folder")
                    .foregroundStyle(folder.colorHex != nil ? folder.color : Color.secondary)
            }
            Text(folder.name)
        }
            .tag(SidebarItem.folder(folder))
            .contextMenu {
                Button {
                    editingFolder = nil
                    newFolderParentId = folder.id
                    showFolderForm = true
                } label: {
                    Label("하위 폴더 추가", systemImage: "folder.badge.plus")
                }
                Button {
                    editingFolder = folder
                    showFolderForm = true
                } label: {
                    Label("편집", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    deleteFolder(folder)
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
            .draggable(FolderTransfer(folderId: folder.id))
            .dropDestination(for: FolderTransfer.self) { items, _ in
                guard let item = items.first else { return false }
                return reparentFolder(item.folderId, into: folder.id)
            }
            .dropDestination(for: NoteTransfer.self) { items, _ in
                guard let item = items.first else { return false }
                return fileNote(item.noteId, into: folder.id)
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

    private func deleteSmartFolder(_ folder: SmartFolder) {
        if case .smartFolder(let sel) = selectedItem, sel.id == folder.id {
            selectedItem = .allNotes
        }
        context.delete(folder)
        try? context.save()
    }

    // MARK: - 폴더 액션

    private func deleteFolder(_ folder: Folder) {
        if case .folder(let sel) = selectedItem, sel.id == folder.id {
            selectedItem = .allNotes
        }
        let folderId = folder.id

        // 하위 폴더는 삭제되는 폴더의 부모로 승격
        for child in allFolders where child.parentId == folderId {
            child.parentId = folder.parentId
        }

        // 폴더 안의 메모는 미분류(루트)로 이동
        let predicate = #Predicate<Note> { $0.folderId == folderId }
        if let notes = try? context.fetch(FetchDescriptor(predicate: predicate)) {
            for note in notes {
                note.folderId = nil
                note.isDirty = true
            }
        }

        IconManager.deleteIcon(urlString: folder.iconImagePath)
        context.delete(folder)
        try? context.save()
    }

    /// folderId 폴더를 targetId 폴더의 하위로 이동. 자기 자신/하위로 이동하는 순환은 차단.
    private func reparentFolder(_ folderId: UUID, into targetId: UUID?) -> Bool {
        guard folderId != targetId else { return false }
        guard let folder = allFolders.first(where: { $0.id == folderId }) else { return false }
        if let targetId, isDescendant(targetId, of: folderId) { return false }

        let siblingCount = allFolders.filter { $0.parentId == targetId }.count
        folder.parentId = targetId
        folder.position = siblingCount
        try? context.save()
        return true
    }

    private func isDescendant(_ candidateId: UUID, of ancestorId: UUID) -> Bool {
        var current = allFolders.first(where: { $0.id == candidateId })
        while let c = current {
            guard let pid = c.parentId else { return false }
            if pid == ancestorId { return true }
            current = allFolders.first(where: { $0.id == pid })
        }
        return false
    }

    private func fileNote(_ noteId: UUID, into folderId: UUID?) -> Bool {
        let predicate = #Predicate<Note> { $0.id == noteId }
        guard let note = try? context.fetch(FetchDescriptor(predicate: predicate)).first else { return false }
        note.folderId = folderId
        note.isDirty = true
        try? context.save()
        return true
    }
}

// MARK: - 폴더 트리 노드

private struct FolderNode: Identifiable {
    let folder: Folder
    var children: [FolderNode]?
    var id: UUID { folder.id }
}
#endif
