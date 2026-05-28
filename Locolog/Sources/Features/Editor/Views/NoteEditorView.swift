import SwiftUI
import SwiftData
import MarkdownUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var locationManager = LocationManager.shared

    @State private var isPreviewMode = false
    @FocusState private var isEditorFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    @Query private var allTags: [Tag]
    @State private var showReminderPicker = false
    @State private var showAIPanel = false

    #if os(macOS)
    @State private var showLocationPicker = false
    #endif

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
        .sheet(isPresented: $showReminderPicker) { reminderSheet }
        .sheet(isPresented: $showAIPanel) {
            AICommandView(note: note) { result in
                note.content += "\n\n" + result
                scheduleAutoSave()
            }
        }
        .onAppear {
            if note.content.isEmpty { isEditorFocused = true }
            Task { await fetchLocationIfNeeded() }
            Task { await NotificationManager.shared.checkStatus() }
        }
        #if os(macOS)
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker) { name, poi in
                guard let name else { return }
                note.locationName = name
                note.locationPOI = poi
                note.isDirty = true
                try? context.save()
            }
        }
        #endif
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
            locationInfo
            Spacer()
            if let reminder = note.reminderAt {
                Label(reminder.formatted(date: .abbreviated, time: .shortened), systemImage: "bell.fill")
                    .font(AppTheme.listMetaFont)
                    .foregroundStyle(reminder > Date() ? Color.accentColor : .secondary)
            }
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(AppTheme.listMetaFont)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppTheme.editorHPadding)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 알림 시트

    private var reminderSheet: some View {
        ReminderPickerView(
            reminderAt: note.reminderAt,
            onSave: { date in
                let old = note.reminderAt
                note.reminderAt = date
                note.isDirty = true
                try? context.save()
                if let date {
                    Task { await setReminder(date: date) }
                } else if old != nil {
                    NotificationManager.shared.cancelReminder(for: note)
                }
            }
        )
    }

    private func setReminder(date: Date) async {
        let manager = NotificationManager.shared
        if !manager.isAuthorized {
            await manager.requestPermission()
        }
        if manager.isAuthorized {
            manager.scheduleReminder(for: note)
        }
    }

    @ViewBuilder
    private var locationInfo: some View {
        if let location = note.displayLocation {
            Label(location, systemImage: "location.fill")
                .font(AppTheme.listMetaFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if case .loading = locationManager.status {
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7)
                Text("위치 가져오는 중...")
                    .font(AppTheme.listMetaFont)
                    .foregroundStyle(.secondary)
            }
        } else {
            #if os(macOS)
            switch locationManager.status {
            case .timedOut, .failed:
                Button {
                    showLocationPicker = true
                } label: {
                    Label("장소 직접 입력", systemImage: "location.slash")
                        .font(AppTheme.listMetaFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
            #endif
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isPreviewMode.toggle() }
                if !isPreviewMode { isEditorFocused = true }
            } label: {
                Label(
                    isPreviewMode ? "편집" : "미리보기",
                    systemImage: isPreviewMode ? "pencil" : "eye"
                )
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showReminderPicker = true } label: {
                Image(systemName: note.reminderAt != nil ? "bell.fill" : "bell")
                    .foregroundStyle(note.reminderAt != nil ? Color.accentColor : .primary)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showAIPanel = true } label: {
                Image(systemName: "sparkles")
                    .foregroundStyle(AIManager.shared.activeProvider != nil ? Color.accentColor : .secondary)
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
            syncTags()
            try? context.save()
            SyncManager.shared.scheduleSync(context: context)
        }
    }

    private func syncTags() {
        let parsed = Set(note.parsedTagNames)
        note.tags = note.tags.filter { parsed.contains($0.name) }
        let existingNames = Set(note.tags.map { $0.name })
        for name in parsed where !existingNames.contains(name) {
            if let existing = allTags.first(where: { $0.name == name }) {
                note.tags.append(existing)
            } else {
                let tag = Tag(name: name)
                context.insert(tag)
                note.tags.append(tag)
            }
        }
    }

    // MARK: - Location

    private func fetchLocationIfNeeded() async {
        guard note.locationName == nil else { return }

        // 방금 다른 메모에서 위치를 성공적으로 받았으면 재활용
        if case .ready = locationManager.status, let name = locationManager.locationName {
            note.locationName = name
            note.locationPOI = locationManager.locationPOI
            note.locationLat = locationManager.currentLocation?.coordinate.latitude
            note.locationLng = locationManager.currentLocation?.coordinate.longitude
            note.isDirty = true
            try? context.save()
            return
        }

        await locationManager.requestLocation()

        switch locationManager.status {
        case .ready:
            note.locationName = locationManager.locationName
            note.locationPOI = locationManager.locationPOI
            note.locationLat = locationManager.currentLocation?.coordinate.latitude
            note.locationLng = locationManager.currentLocation?.coordinate.longitude
            note.isDirty = true
            try? context.save()
        case .timedOut, .failed:
            #if os(macOS)
            showLocationPicker = true
            #endif
        default:
            break
        }
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
