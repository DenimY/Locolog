import SwiftUI
import SwiftData

struct CategoryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.position) private var categories: [Category]

    var editing: Category? = nil

    @State private var name = ""
    @State private var selectedColor = CategoryFormView.palette[0]

    static let palette: [String] = [
        "#4A90E2", "#5AC8FA", "#34C759", "#FF9500",
        "#FF3B30", "#AF52DE", "#FF2D55", "#FFCC00",
        "#8E8E93", "#636366"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("카테고리 이름", text: $name)
                }
                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            selectedColor == hex ? Color.primary : .clear,
                                            lineWidth: 3
                                        )
                                        .padding(2)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(editing == nil ? "새 카테고리" : "카테고리 편집")
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
            if let cat = editing {
                name = cat.name
                selectedColor = cat.colorHex
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let cat = editing {
            cat.name = trimmed
            cat.colorHex = selectedColor
        } else {
            let cat = Category(name: trimmed, colorHex: selectedColor, position: categories.count)
            context.insert(cat)
        }
        try? context.save()
        dismiss()
    }
}
