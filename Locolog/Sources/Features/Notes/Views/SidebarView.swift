import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedCategory: Category?
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(selection: $selectedCategory) {
            // 전체 메모
            Label("전체 메모", systemImage: "tray.full")
                .tag(Optional<Category>.none)

            // 카테고리
            if !categories.isEmpty {
                Section("카테고리") {
                    ForEach(categories) { category in
                        Label(category.name, systemImage: "folder.fill")
                            .tag(Optional(category))
                    }
                }
            }

            // 스마트 폴더
            if !smartFolders.isEmpty {
                Section("스마트 폴더") {
                    ForEach(smartFolders) { folder in
                        Label(folder.name, systemImage: "folder.badge.gearshape")
                    }
                }
            }
        }
        .navigationTitle("Locolog")
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }
}
