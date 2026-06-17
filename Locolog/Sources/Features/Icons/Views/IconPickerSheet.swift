import SwiftUI
import PhotosUI

private let curatedEmoji: [String] = [
    "😀", "😂", "😍", "🤔", "😎", "🥳", "😴", "🤯",
    "👍", "👏", "🙏", "💪", "✌️", "🤝", "👀", "🔥",
    "⭐️", "✨", "🎉", "🎯", "💡", "📌", "📍", "🔖",
    "📝", "📒", "📚", "📖", "🗂️", "📁", "📅", "🗓️",
    "✅", "☑️", "❗️", "❓", "⚠️", "🚀", "🏆", "🎁",
    "💼", "🧳", "🛫", "🗺️", "🏠", "🏢", "🏖️", "⛰️",
    "🍀", "🌱", "🌳", "🌸", "🌞", "🌙", "☔️", "❄️",
    "☕️", "🍔", "🍕", "🍰", "🍎", "🍇", "🍺", "🍷",
    "⚽️", "🏀", "🎮", "🎵", "🎬", "📷", "🎨", "✏️",
    "💻", "📱", "⌚️", "💰", "💳", "🛒", "🏥", "💊",
    "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍",
    "🐶", "🐱", "🐰", "🦊", "🐼", "🦄", "🐢", "🦋",
]

struct IconPickerSheet: View {
    var ownerId: UUID
    var currentEmoji: String?
    var currentImagePath: String?
    var onSetEmoji: (String?) -> Void
    var onSetImage: (Data) -> Void
    var onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customEmojiInput = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingImage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("직접 입력")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("이모지를 입력하거나 붙여넣으세요", text: $customEmojiInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customEmojiInput) { _, newValue in
                                guard let first = newValue.first else { return }
                                onSetEmoji(String(first))
                                dismiss()
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("이모지 선택")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(curatedEmoji, id: \.self) { emoji in
                                Button {
                                    onSetEmoji(emoji)
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 26))
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("이미지 업로드")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(isLoadingImage ? "불러오는 중..." : "이미지 선택", systemImage: "photo.badge.plus")
                        }
                        .disabled(isLoadingImage)
                        .onChange(of: selectedPhotoItem) { _, item in
                            guard let item else { return }
                            isLoadingImage = true
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    onSetImage(data)
                                    dismiss()
                                }
                                isLoadingImage = false
                            }
                        }
                    }

                    if currentEmoji != nil || currentImagePath != nil {
                        Button(role: .destructive) {
                            onRemove()
                            dismiss()
                        } label: {
                            Label("아이콘 제거", systemImage: "xmark.circle")
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("아이콘 설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 380, height: 480)
        #endif
    }
}
