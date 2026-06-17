import SwiftUI

/// 아이콘(이모지/이미지)을 보여주고 탭하면 IconPickerSheet를 띄우는 버튼
struct IconPickerButton: View {
    var ownerId: UUID
    var emoji: String?
    var imagePath: String?
    var fallbackSymbol: String
    var size: CGFloat = 28
    var onSetEmoji: (String?) -> Void
    var onSetImagePath: (String?) -> Void
    var onRemove: () -> Void

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            IconView(emoji: emoji, imagePath: imagePath, fallbackSymbol: fallbackSymbol, size: size)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.22))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            IconPickerSheet(
                ownerId: ownerId,
                currentEmoji: emoji,
                currentImagePath: imagePath,
                onSetEmoji: { newEmoji in
                    if let oldPath = imagePath { IconManager.deleteIcon(urlString: oldPath) }
                    onSetImagePath(nil)
                    onSetEmoji(newEmoji)
                },
                onSetImage: { data in
                    if let oldPath = imagePath { IconManager.deleteIcon(urlString: oldPath) }
                    if let savedPath = try? IconManager.saveIcon(data, for: ownerId) {
                        onSetEmoji(nil)
                        onSetImagePath(savedPath)
                    }
                },
                onRemove: {
                    if let oldPath = imagePath { IconManager.deleteIcon(urlString: oldPath) }
                    onSetEmoji(nil)
                    onSetImagePath(nil)
                }
            )
        }
    }
}
