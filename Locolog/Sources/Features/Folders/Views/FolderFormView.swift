import SwiftUI
import SwiftData

struct FolderFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allFolders: [Folder]

    var editing: Folder? = nil
    var parentId: UUID? = nil

    @State private var name = ""
    @State private var selectedColor: String? = nil
    @State private var iconEmoji: String? = nil
    @State private var iconImagePath: String? = nil
    @State private var formId = UUID()

    static let palette: [String] = [
        "#4A90E2", "#5AC8FA", "#34C759", "#FF9500",
        "#FF3B30", "#AF52DE", "#FF2D55", "#FFCC00",
        "#8E8E93", "#636366"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    HStack(spacing: 12) {
                        IconPickerButton(
                            ownerId: formId,
                            emoji: iconEmoji,
                            imagePath: iconImagePath,
                            fallbackSymbol: "folder",
                            size: 36,
                            onSetEmoji: { iconEmoji = $0 },
                            onSetImagePath: { iconImagePath = $0 },
                            onRemove: { iconEmoji = nil; iconImagePath = nil }
                        )
                        TextField("", text: $name, prompt: Text("폴더 이름"))
                    }
                }
                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        colorSwatch(nil)
                        ForEach(Self.palette, id: \.self) { hex in
                            colorSwatch(hex)
                        }
                    }
                    .padding(.vertical, 4)
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
            if let folder = editing {
                name = folder.name
                selectedColor = folder.colorHex
                iconEmoji = folder.iconEmoji
                iconImagePath = folder.iconImagePath
                formId = folder.id
            }
        }
    }

    @ViewBuilder
    private func colorSwatch(_ hex: String?) -> some View {
        Circle()
            .fill(hex.flatMap { Color(hex: $0) } ?? Color.secondary.opacity(0.3))
            .frame(width: 36, height: 36)
            .overlay {
                if hex == nil {
                    Image(systemName: "slash.circle").foregroundStyle(.secondary)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(selectedColor == hex ? Color.primary : .clear, lineWidth: 3)
                    .padding(2)
            )
            .onTapGesture { selectedColor = hex }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let folder = editing {
            folder.name = trimmed
            folder.colorHex = selectedColor
            folder.iconEmoji = iconEmoji
            folder.iconImagePath = iconImagePath
        } else {
            let siblingCount = allFolders.filter { $0.parentId == parentId }.count
            let folder = Folder(name: trimmed, parentId: parentId, position: siblingCount, colorHex: selectedColor)
            folder.id = formId
            folder.iconEmoji = iconEmoji
            folder.iconImagePath = iconImagePath
            context.insert(folder)
        }
        try? context.save()
        dismiss()
    }
}
