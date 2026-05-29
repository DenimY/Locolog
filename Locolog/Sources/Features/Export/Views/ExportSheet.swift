import SwiftUI

struct ExportSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var mdURL: URL?
    @State private var errorMessage: String?

    #if os(iOS)
    @State private var pdfURL: URL?
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    exportRow(
                        icon: "doc.text",
                        title: "Markdown (.md)",
                        subtitle: "다른 앱이나 편집기에서 열 수 있습니다",
                        color: .blue
                    ) {
                        if let url = try? ExportManager.markdownFileURL(for: note) {
                            mdURL = url
                        } else {
                            errorMessage = "Markdown 파일 생성에 실패했습니다."
                        }
                    }

                    #if os(iOS)
                    exportRow(
                        icon: "doc.richtext",
                        title: "PDF",
                        subtitle: "공유 및 인쇄에 적합합니다",
                        color: .red
                    ) {
                        if let url = try? ExportManager.pdfFileURL(for: note) {
                            pdfURL = url
                        } else {
                            errorMessage = "PDF 생성에 실패했습니다."
                        }
                    }
                    #endif
                } header: {
                    Text("내보내기 형식")
                } footer: {
                    Text("내보낸 파일은 공유 시트를 통해 저장하거나 다른 앱으로 보낼 수 있습니다.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("내보내기")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            // Markdown 공유
            .sheet(item: $mdURL) { url in
                ShareSheetView(url: url)
            }
            #if os(iOS)
            // PDF 공유
            .sheet(item: $pdfURL) { url in
                ShareSheetView(url: url)
            }
            #endif
        }
        #if os(macOS)
        .frame(width: 360, height: 280)
        #endif
    }

    private func exportRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - 플랫폼별 공유 시트

struct ShareSheetView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        ActivityViewController(url: url)
            .ignoresSafeArea()
        #else
        VStack(spacing: 16) {
            Text("파일이 준비됐습니다")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("저장 위치 열기") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.bordered)
                Button("공유...") {
                    let picker = NSSharingServicePicker(items: [url])
                    picker.show(relativeTo: .zero, of: NSApp.keyWindow?.contentView ?? NSView(), preferredEdge: .minY)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("닫기") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 320, height: 180)
        #endif
    }
}

// MARK: - iOS UIActivityViewController 래퍼

#if os(iOS)
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
