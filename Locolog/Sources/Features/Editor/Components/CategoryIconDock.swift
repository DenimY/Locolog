import SwiftUI
import SwiftData

/// 에디터 상단 아이콘 독. 끌어다 본문에 놓거나 탭하면 분류된다.
struct CategoryIconDock: View {
    let folders: [Folder]
    let selectedFolderId: UUID?
    let onStamp: (CategoryStampPreset?, Folder?, Bool) -> Void

    private var extraFolders: [Folder] {
        let matched = Set(CategoryStampPreset.allCases.compactMap { $0.matchingFolder(in: folders)?.id })
        return folders
            .filter { $0.parentId == nil && !matched.contains($0.id) }
            .sorted { $0.position < $1.position }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CategoryStampPreset.allCases) { preset in
                    let folder = preset.matchingFolder(in: folders)
                    stampCell(
                        emoji: preset.emoji,
                        imagePath: folder?.iconImagePath,
                        name: preset.name,
                        color: Color(hex: preset.colorHex) ?? Color.accentColor,
                        isSelected: folder.map { selectedFolderId == $0.id } ?? false
                    )
                    .draggable(CategoryStampTransfer(presetRaw: preset.rawValue, folderId: folder?.id))
                    .onTapGesture { onStamp(preset, folder, true) }
                }

                if !extraFolders.isEmpty {
                    Divider().frame(height: 28)
                    ForEach(extraFolders) { folder in
                        stampCell(
                            emoji: folder.iconEmoji,
                            imagePath: folder.iconImagePath,
                            name: folder.name,
                            color: folder.color,
                            isSelected: selectedFolderId == folder.id
                        )
                        .draggable(CategoryStampTransfer(folderId: folder.id))
                        .onTapGesture { onStamp(nil, folder, true) }
                    }
                }
            }
            .padding(.horizontal, AppTheme.editorHPadding)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("분류 아이콘")
    }

    private func stampCell(
        emoji: String?,
        imagePath: String?,
        name: String,
        color: Color,
        isSelected: Bool
    ) -> some View {
        IconView(
            emoji: emoji,
            imagePath: imagePath,
            fallbackSymbol: "folder",
            size: 28
        )
        .frame(width: 36, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(isSelected ? 0.28 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5)
        )
        .accessibilityLabel(name)
        .help(name)
    }
}
