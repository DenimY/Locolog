import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// 에디터 하단 이미지 첨부 미리보기 바
struct AttachmentBar: View {
    let urlStrings: [String]
    let onDelete: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(urlStrings, id: \.self) { urlString in
                    AttachmentThumbnail(urlString: urlString) {
                        onDelete(urlString)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 90)
        .background(.bar)
    }
}

// MARK: - 개별 썸네일

struct AttachmentThumbnail: View {
    let urlString: String
    let onDelete: () -> Void

    @State private var image: PlatformImage?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image {
                    PlatformImageView(image: img)
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .overlay {
                            ProgressView().scaleEffect(0.7)
                        }
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 삭제 버튼
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)).padding(-2))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .confirmationDialog("이미지를 삭제하시겠습니까?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { onDelete() }
            Button("취소", role: .cancel) {}
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard let url = URL(string: urlString), url.isFileURL else { return }
        let data = try? Data(contentsOf: url)
        guard let data else { return }
        #if os(iOS)
        image = UIImage(data: data)
        #else
        image = NSImage(data: data)
        #endif
    }
}

// MARK: - 플랫폼 타입 추상화

#if os(iOS)
typealias PlatformImage = UIImage

struct PlatformImageView: View {
    let image: UIImage
    var body: some View { Image(uiImage: image).resizable() }
}
#else
typealias PlatformImage = NSImage

struct PlatformImageView: View {
    let image: NSImage
    var body: some View { Image(nsImage: image).resizable() }
}
#endif
