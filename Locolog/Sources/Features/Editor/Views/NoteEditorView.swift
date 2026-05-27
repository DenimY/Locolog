import SwiftUI
import SwiftData
import MarkdownUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var locationManager = LocationManager.shared

    @State private var isPreviewMode = false
    @FocusState private var isEditorFocused: Bool

    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                editorContent
                    .opacity(isPreviewMode ? 0 : 1)

                previewContent
                    .opacity(isPreviewMode ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.15), value: isPreviewMode)

            metadataBar
        }
        .navigationTitle(note.displayTitle.isEmpty ? "새 메모" : note.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarItems }
        .onAppear {
            if note.content.isEmpty {
                isEditorFocused = true
            }
            Task { await fetchLocationIfNeeded() }
        }
    }

    // MARK: - Editor

    private var editorContent: some View {
        TextEditor(text: $note.content)
            .font(AppTheme.noteBodyFont)
            .padding(.horizontal, AppTheme.editorHPadding)
            .focused($isEditorFocused)
            .onChange(of: note.content) { _, _ in scheduleAutoSave() }
            #if os(iOS)
            .toolbar { codeToolbar }
            #endif
    }

    // MARK: - Preview

    private var previewContent: some View {
        ScrollView {
            Markdown(note.content.isEmpty ? "_내용을 입력하세요_" : note.content)
                .markdownCodeSyntaxHighlighter(HighlightrCodeSyntaxHighlighter(colorScheme: colorScheme))
                .markdownTheme(.gitHub)
                .padding(AppTheme.editorHPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
        HStack(spacing: 8) {
            if let location = note.displayLocation {
                Label(location, systemImage: "location.fill")
                    .font(AppTheme.listMetaFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if case .loading = locationManager.status {
                ProgressView()
                    .scaleEffect(0.7)
                Text("위치 가져오는 중...")
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
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPreviewMode.toggle()
                }
                if !isPreviewMode { isEditorFocused = true }
            } label: {
                Label(
                    isPreviewMode ? "편집" : "미리보기",
                    systemImage: isPreviewMode ? "pencil" : "eye"
                )
            }
        }
    }

    // MARK: - Auto-save (0.3s debounce)

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

    // MARK: - Location

    private func fetchLocationIfNeeded() async {
        guard note.locationName == nil else { return }
        await locationManager.requestLocation()
        guard case .ready = locationManager.status else { return }
        note.locationName  = locationManager.locationName
        note.locationPOI   = locationManager.locationPOI
        note.locationLat   = locationManager.currentLocation?.coordinate.latitude
        note.locationLng   = locationManager.currentLocation?.coordinate.longitude
        note.isDirty = true
        try? context.save()
    }
}

// MARK: - iOS: 키보드 위 코드 툴바

#if os(iOS)
extension NoteEditorView {
    @ToolbarContentBuilder
    private var codeToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            CodeAccessoryToolbar { snippet in
                note.content += snippet
            }
        }
    }
}
#endif
