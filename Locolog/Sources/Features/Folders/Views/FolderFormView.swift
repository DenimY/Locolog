import SwiftUI
import SwiftData

struct FolderFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allFolders: [Folder]

    var editing: Folder? = nil
    var parentId: UUID? = nil

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("", text: $name, prompt: Text("폴더 이름"))
                }
            }
            .navigationTitle(editing == nil ? "새 폴더" : "폴더 편집")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let folder = editing { name = folder.name }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let folder = editing {
            folder.name = trimmed
        } else {
            let siblingCount = allFolders.filter { $0.parentId == parentId }.count
            let folder = Folder(name: trimmed, parentId: parentId, position: siblingCount)
            context.insert(folder)
        }
        try? context.save()
        dismiss()
    }
}
