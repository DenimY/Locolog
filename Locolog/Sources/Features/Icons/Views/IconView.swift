import SwiftUI

/// 노트/폴더의 커스텀 아이콘(이미지 > 이모지 > 기본 SF Symbol 순) 표시
struct IconView: View {
    var emoji: String?
    var imagePath: String?
    var fallbackSymbol: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let imagePath, let url = URL(string: imagePath), url.isFileURL,
               let platformImage = loadPlatformImage(contentsOfFile: url.path) {
                platformImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.85))
                    .frame(width: size, height: size)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.7))
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - 플랫폼 공용 이미지 로더

#if os(iOS)
import UIKit
private func loadPlatformImage(contentsOfFile path: String) -> Image? {
    guard let img = UIImage(contentsOfFile: path) else { return nil }
    return Image(uiImage: img)
}
#else
import AppKit
private func loadPlatformImage(contentsOfFile path: String) -> Image? {
    guard let img = NSImage(contentsOfFile: path) else { return nil }
    return Image(nsImage: img)
}
#endif
