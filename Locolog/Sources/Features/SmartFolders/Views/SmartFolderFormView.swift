import SwiftUI
import SwiftData

struct SmartFolderFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]

    var editing: SmartFolder? = nil

    @State private var name = ""
    @State private var selectedCategoryId: UUID? = nil
    @State private var locationName = ""
    @State private var tagName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("스마트 폴더 이름", text: $name)
                }
                Section("필터 조건") {
                    Picker("카테고리", selection: $selectedCategoryId) {
                        Text("전체").tag(UUID?.none)
                        ForEach(categories) { cat in
                            Label(cat.name, systemImage: "folder.fill")
                                .foregroundStyle(cat.color)
                                .tag(Optional(cat.id))
                        }
                    }
                    HStack {
                        Label("장소", systemImage: "location")
                        Spacer()
                        TextField("예: 강남구", text: $locationName)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("태그", systemImage: "tag")
                        Spacer()
                        TextField("예: python", text: $tagName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if !name.isEmpty || editing != nil {
                    Section("미리보기") {
                        filterPreview
                    }
                }
            }
            .navigationTitle(editing == nil ? "새 스마트 폴더" : "스마트 폴더 편집")
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
            if let sf = editing {
                name = sf.name
                let f = sf.filter
                selectedCategoryId = f.categoryId
                locationName = f.locationName ?? ""
                tagName = f.tagNames.first ?? ""
            }
        }
    }

    private var filterPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let catId = selectedCategoryId,
               let cat = categories.first(where: { $0.id == catId }) {
                Label(cat.name, systemImage: "folder.fill")
                    .foregroundStyle(cat.color)
            }
            if !locationName.isEmpty {
                Label(locationName, systemImage: "location")
            }
            if !tagName.isEmpty {
                Label("#\(tagName)", systemImage: "tag")
            }
            if selectedCategoryId == nil && locationName.isEmpty && tagName.isEmpty {
                Text("조건 없음 — 전체 메모 표시")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var filter = NoteFilter()
        filter.categoryId = selectedCategoryId
        filter.locationName = locationName.isEmpty ? nil : locationName
        let tag = tagName.trimmingCharacters(in: .whitespaces)
        filter.tagNames = tag.isEmpty ? [] : [tag]

        if let sf = editing {
            sf.name = trimmed
            sf.filterJSON = (try? JSONEncoder().encode(filter))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        } else {
            let sf = SmartFolder(name: trimmed, filter: filter, position: smartFolders.count)
            context.insert(sf)
        }
        try? context.save()
        dismiss()
    }
}
