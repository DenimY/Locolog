#if os(iOS)
import SwiftUI
import SwiftData

/// NavigationPath에 루트(미분류 최상위) 진입을 표시하기 위한 마커
struct FolderRootMarker: Hashable {}

/// iOS 폴더 트리 드릴다운 화면 (Apple Notes 스타일) — 폴더 탭 시 다음 화면으로 push
struct FolderBrowserView: View {
    var folder: Folder?   // nil이면 최상위

    @Environment(\.modelContext) private var context
    @Query private var allFolders: [Folder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var showFolderForm = false
    @State private var editingFolder: Folder?
    @State private var movingNote: Note?

    private var subfolders: [Folder] {
        allFolders
            .filter { $0.parentId == folder?.id }
            .sorted { $0.position < $1.position }
    }

    private var notesHere: [Note] {
        allNotes.filter { !$0.isDeleted && $0.folderId == folder?.id }
    }

    var body: some View {
        Group {
            if subfolders.isEmpty && notesHere.isEmpty {
                ContentUnavailableView {
                    Label("폴더가 비었습니다", systemImage: "folder")
                } description: {
                    Text("새 하위 폴더나 메모를 추가하세요.")
                }
            } else {
                List {
                    if !subfolders.isEmpty {
                        Section("폴더") {
                            ForEach(subfolders) { sub in
                                NavigationLink(value: sub) {
                                    folderRow(sub)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { deleteFolder(sub) } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        editingFolder = sub
                                        showFolderForm = true
                                    } label: {
                                        Label("편집", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { deleteFolder(sub) } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    if !notesHere.isEmpty {
                        Section("메모") {
                            ForEach(notesHere) { note in
                                NavigationLink(value: note) {
                                    NoteRowView(note: note, color: nil)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { deleteNote(note) } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button { movingNote = note } label: {
                                        Label("폴더로 이동", systemImage: "folder")
                                    }
                                    if note.folderId != nil {
                                        Button {
                                            note.folderId = nil
                                            note.isDirty = true
                                            try? context.save()
                                        } label: {
                                            Label("폴더에서 제거", systemImage: "folder.badge.minus")
                                        }
                                    }
                                    Button(role: .destructive) { deleteNote(note) } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey(folder?.name ?? "모든 폴더"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editingFolder = nil
                        showFolderForm = true
                    } label: {
                        Label("새 하위 폴더", systemImage: "folder.badge.plus")
                    }
                    Button {
                        createNoteHere()
                    } label: {
                        Label("새 메모", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showFolderForm) {
            FolderFormView(editing: editingFolder, parentId: folder?.id)
        }
        .sheet(item: $movingNote) { note in
            FolderPickerSheet(note: note)
        }
    }

    @ViewBuilder
    private func folderRow(_ sub: Folder) -> some View {
        HStack(spacing: 8) {
            if sub.iconEmoji != nil || sub.iconImagePath != nil {
                IconView(emoji: sub.iconEmoji, imagePath: sub.iconImagePath, fallbackSymbol: "folder", size: 18)
            } else {
                Image(systemName: "folder")
                    .foregroundStyle(sub.colorHex != nil ? sub.color : Color.secondary)
            }
            Text(sub.name)
            Spacer()
            let count = directNoteCount(in: sub)
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func directNoteCount(in folder: Folder) -> Int {
        allNotes.filter { !$0.isDeleted && $0.folderId == folder.id }.count
    }

    // MARK: - 액션

    private func createNoteHere() {
        let note = Note()
        note.folderId = folder?.id
        context.insert(note)
        try? context.save()
    }

    private func deleteNote(_ note: Note) {
        note.isDeleted = true
        note.isDirty = true
        try? context.save()
    }

    private func deleteFolder(_ target: Folder) {
        let folderId = target.id
        for child in allFolders where child.parentId == folderId {
            child.parentId = target.parentId
        }
        for note in allNotes where note.folderId == folderId {
            note.folderId = nil
            note.isDirty = true
        }
        IconManager.deleteIcon(urlString: target.iconImagePath)
        context.delete(target)
        try? context.save()
    }
}

// MARK: - 메모를 다른 폴더로 이동하는 시트

struct FolderPickerSheet: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allFolders: [Folder]

    private struct FlatItem: Identifiable {
        let folder: Folder
        let depth: Int
        var id: UUID { folder.id }
    }

    private var flattenedFolders: [FlatItem] {
        var result: [FlatItem] = []
        func walk(parentId: UUID?, depth: Int) {
            let children = allFolders
                .filter { $0.parentId == parentId }
                .sorted { $0.position < $1.position }
            for child in children {
                result.append(FlatItem(folder: child, depth: depth))
                walk(parentId: child.id, depth: depth + 1)
            }
        }
        walk(parentId: nil, depth: 0)
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    move(to: nil)
                } label: {
                    HStack {
                        Label("미분류", systemImage: "tray")
                            .foregroundStyle(.primary)
                        if note.folderId == nil {
                            Spacer()
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                ForEach(flattenedFolders) { item in
                    Button {
                        move(to: item.folder.id)
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(item.folder.colorHex != nil ? item.folder.color : Color.secondary)
                            Text(item.folder.name)
                                .foregroundStyle(.primary)
                            if note.folderId == item.folder.id {
                                Spacer()
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.leading, CGFloat(item.depth) * 16)
                    }
                }
            }
            .navigationTitle("폴더로 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func move(to folderId: UUID?) {
        note.folderId = folderId
        note.isDirty = true
        try? context.save()
        dismiss()
    }
}
#endif
