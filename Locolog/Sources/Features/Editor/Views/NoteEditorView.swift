import SwiftUI
import SwiftData
import MarkdownUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @StateObject private var locationManager = LocationManager.shared

    @State private var isPreviewMode = false
    @FocusState private var isEditorFocused: Bool

    // 자동저장: 0.3초 디바운스
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // 에디터 / 프리뷰 전환
            if isPreviewMode {
                previewContent
            } else {
                editorContent
            }

            // 하단 메타데이터 바
            metadataBar
        }
        .toolbar { toolbarItems }
        .task { await fetchLocationIfNeeded() }
    }

    // MARK: - Editor
    private var editorContent: some View {
        TextEditor(text: $note.content)
            .font(AppTheme.noteBodyFont)
            .padding(.horizontal, AppTheme.editorHPadding)
            .focused($isEditorFocused)
            .onChange(of: note.content) { _, _ in scheduleAutoSave() }
            #if os(iOS)
            .toolbar(content: { codeToolbar })
            #endif
    }

    // MARK: - Preview
    private var previewContent: some View {
        ScrollView {
            Markdown(note.content)
                .padding(AppTheme.editorHPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metadata Bar
    private var metadataBar: some View {
        HStack(spacing: 12) {
            if let location = note.displayLocation {
                Label(location, systemImage: "location.fill")
                    .font(AppTheme.listMetaFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTheme.listMetaFont)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppTheme.editorHPadding)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isPreviewMode.toggle()
            } label: {
                Label(isPreviewMode ? "편집" : "미리보기",
                      systemImage: isPreviewMode ? "pencil" : "eye")
            }
        }
    }

    // MARK: - 자동저장 (디바운스 0.3s)
    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            note.updatedAt = Date()
            note.isDirty = true
            try? context.save()
        }
    }

    // MARK: - 위치 요청
    private func fetchLocationIfNeeded() async {
        guard note.locationName == nil else { return }
        await locationManager.requestLocation()
        if case .ready = locationManager.status {
            note.locationName = locationManager.locationName
            note.locationPOI = locationManager.locationPOI
            note.locationLat = locationManager.currentLocation?.coordinate.latitude
            note.locationLng = locationManager.currentLocation?.coordinate.longitude
            note.isDirty = true
            try? context.save()
        }
    }
}

// MARK: - iOS: Input Accessory View (코드 툴바)
#if os(iOS)
extension NoteEditorView {
    private var codeToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            CodeAccessoryToolbar(onInsert: insertText)
        }
    }

    private func insertText(_ text: String) {
        // TextEditor에 직접 텍스트 삽입 (커서 위치)
        // SwiftUI TextEditor는 커서 위치 접근이 제한적 → 임시로 끝에 추가
        note.content += text
    }
}
#endif
