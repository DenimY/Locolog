import SwiftUI
import SwiftData
import MarkdownUI
import PhotosUI
#if os(iOS)
import UIKit
#endif

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var locationManager = LocationManager.shared
    @Query private var allFolders: [Folder]

    @FocusState private var isEditorFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var saveTask: Task<Void, Never>?
    @State private var hasUnsavedChanges = false
    @State private var showReminderPicker = false
    @State private var showAIPanel = false
    @State private var showExportSheet = false
    @State private var showIconPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isDropTargeted = false

    // 노트 전환 시 onChange(of: note.content)가 스푸리어스하게 발동하는 SwiftUI 버그 방어용
    // TextEditor는 localContent에 바인딩하고, 실제 유저 편집만 note.content에 반영한다.
    @State private var localContent: String
    @State private var isExternalContentUpdate = false

    init(note: Note) {
        _note = Bindable(note)
        _localContent = State(initialValue: note.content)
    }

    #if os(macOS)
    @State private var showLocationPicker = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            iconBar

            ZStack {
                editorContent
                    .opacity(note.isPreviewMode ? 0 : 1)

                previewContent
                    .opacity(note.isPreviewMode ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.15), value: note.isPreviewMode)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: CategoryStampTransfer.self) { items, _ in
                guard let item = items.first else { return false }
                let folder = item.folderId.flatMap { id in allFolders.first { $0.id == id } }
                applyStamp(preset: item.preset, folder: folder, toggleIfSame: false)
                return true
            } isTargeted: { isDropTargeted = $0 }

            // 이미지 첨부 바
            if !note.attachmentURLs.isEmpty {
                Divider()
                AttachmentBar(urlStrings: note.attachmentURLs) { urlString in
                    deleteAttachment(urlString)
                }
            }

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
                if localContent.isEmpty {
                    localContent = result
                } else {
                    localContent += "\n\n" + result
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(note: note)
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerSheet(
                ownerId: note.id,
                currentEmoji: note.iconEmoji,
                currentImagePath: note.iconImagePath,
                onSetEmoji: { newEmoji in
                    if let oldPath = note.iconImagePath { IconManager.deleteIcon(urlString: oldPath) }
                    note.iconImagePath = nil
                    note.iconEmoji = newEmoji
                    note.saveDirty(in: context)
                },
                onSetImage: { data in
                    if let oldPath = note.iconImagePath { IconManager.deleteIcon(urlString: oldPath) }
                    if let savedPath = try? IconManager.saveIcon(data, for: note.id) {
                        note.iconEmoji = nil
                        note.iconImagePath = savedPath
                        note.saveDirty(in: context)
                    }
                },
                onRemove: {
                    if let oldPath = note.iconImagePath { IconManager.deleteIcon(urlString: oldPath) }
                    note.iconEmoji = nil
                    note.iconImagePath = nil
                    note.saveDirty(in: context)
                }
            )
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await addAttachments(from: items) }
        }
        // 유저 편집: 즉시 isDirty (pull 덮어쓰기 방지), 디스크 쓰기는 0.3초 디바운스
        .onChange(of: localContent) { _, newValue in
            guard !isExternalContentUpdate else {
                isExternalContentUpdate = false
                return
            }
            note.content = newValue
            note.isDirty = true
            scheduleAutoSave()
        }
        // 외부 변경(노트 전환·동기화): note.content 변경 → localContent 갱신 (자동저장 없음)
        .onChange(of: note.content) { _, newValue in
            guard localContent != newValue else { return }
            isExternalContentUpdate = true
            localContent = newValue
        }
        // 뷰가 재사용될 때: 이전 노트의 in-memory 변경을 저장하고 편집 버퍼만 교체
        .onChange(of: note.id) { _, _ in
            saveTask?.cancel()
            saveTask = nil
            try? context.save()
            if localContent != note.content {
                isExternalContentUpdate = true
                localContent = note.content
            } else {
                isExternalContentUpdate = false
            }
            hasUnsavedChanges = false
        }
        .onAppear {
            if note.content.isEmpty { isEditorFocused = true }
            Task { await fetchLocationIfNeeded() }
            Task { await NotificationManager.shared.checkStatus() }
        }
        .onDisappear {
            flushSaveIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                flushSaveIfNeeded()
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker) { name, poi in
                guard let name else { return }
                note.locationName = name
                note.locationPOI = poi
                note.saveDirty(in: context)
            }
        }
        #endif
    }

    // MARK: - 분류 아이콘 독

    private var iconBar: some View {
        VStack(spacing: 0) {
            CategoryIconDock(
                folders: allFolders,
                selectedFolderId: note.folderId
            ) { preset, folder, toggle in
                applyStamp(preset: preset, folder: folder, toggleIfSame: toggle)
            }
            Divider()
        }
    }

    private var assignedFolder: Folder? {
        guard let id = note.folderId else { return nil }
        return allFolders.first { $0.id == id }
    }

    // MARK: - Editor

    private var editorContent: some View {
        TextEditor(text: $localContent)
            .font(AppTheme.noteBodyFont)
            .padding(.horizontal, AppTheme.editorHPadding)
            .focused($isEditorFocused)
            #if os(iOS)
            .toolbar { codeToolbar }
            #endif
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewContent: some View {
        if note.noteType == .log {
            LogRendererView(content: note.content)
        } else {
            ScrollView {
                Markdown(note.content.isEmpty ? "_내용을 입력하세요_" : note.content)
                    .markdownCodeSyntaxHighlighter(HighlightrCodeSyntaxHighlighter(colorScheme: colorScheme))
                    .markdownTheme(adaptiveMarkdownTheme)
                    .padding(AppTheme.editorHPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #if os(macOS)
            .background(Color(.textBackgroundColor))
            #endif
        }
    }

    private var adaptiveMarkdownTheme: Theme {
        colorScheme == .dark ? darkMarkdownTheme : .gitHub
    }

    private var darkMarkdownTheme: Theme {
        Theme()
            .text { ForegroundColor(.primary) }
            .link { ForegroundColor(Color(red: 0.4, green: 0.7, blue: 1.0)) }
            .heading1 { label in
                label
                    .markdownTextStyle { FontWeight(.bold); FontSize(.em(1.8)) }
                    .markdownMargin(top: 16, bottom: 8)
            }
            .heading2 { label in
                label
                    .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.4)) }
                    .markdownMargin(top: 14, bottom: 6)
            }
            .heading3 { label in
                label
                    .markdownTextStyle { FontWeight(.semibold); FontSize(.em(1.1)) }
                    .markdownMargin(top: 12, bottom: 4)
            }
            .code {
                FontFamilyVariant(.monospaced)
                BackgroundColor(Color.white.opacity(0.1))
                ForegroundColor(Color(red: 0.95, green: 0.55, blue: 0.55))
            }
            .codeBlock { config in
                config.label
                    .markdownTextStyle { FontFamilyVariant(.monospaced); FontSize(.em(0.9)) }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.13, green: 0.14, blue: 0.16)))
                    .markdownMargin(top: 8, bottom: 8)
            }
            .blockquote { config in
                config.label
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.3)).frame(width: 3)
                    }
                    .markdownTextStyle { ForegroundColor(.secondary) }
            }
    }

    // MARK: - Metadata Bar

    private var metadataBar: some View {
        HStack(spacing: 8) {
            locationInfo
            if let folder = assignedFolder {
                Text([folder.iconEmoji, folder.name].compactMap { $0 }.joined(separator: " "))
                    .font(AppTheme.listMetaFont)
                    .foregroundStyle(folder.color)
                    .lineLimit(1)
            }
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
                note.saveDirty(in: context)
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
        // 블록 삽입 메뉴
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section("텍스트") {
                    Button("제목 1")          { insertBlock("# ") }
                    Button("제목 2")          { insertBlock("## ") }
                    Button("제목 3")          { insertBlock("### ") }
                }
                Section("목록") {
                    Button("글머리 기호")     { insertBlock("- ") }
                    Button("번호 목록")       { insertBlock("1. ") }
                    Button("할 일 체크박스") { insertBlock("- [ ] ") }
                }
                Section("삽입") {
                    Button("코드 블록")       { insertBlock("```\n\n```") }
                    Button("인용")           { insertBlock("> ") }
                    Button("구분선")         { insertBlock("\n---\n") }
                }
                Divider()
                Section("분류") {
                    Button("메모 아이콘") { showIconPicker = true }
                }
                Section("노트 타입") {
                    ForEach(NoteType.allCases, id: \.rawValue) { type in
                        Button {
                            note.noteType = type
                            note.saveDirty(in: context)
                        } label: {
                            Label(LocalizedStringKey(type.label), systemImage: type.icon)
                        }
                        .disabled(note.noteType == type)
                    }
                }
            } label: {
                Image(systemName: "plus.circle")
            }
        }
        // 편집/미리보기 토글
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { note.isPreviewMode.toggle() }
                if !note.isPreviewMode { isEditorFocused = true }
            } label: {
                Label(
                    note.isPreviewMode ? "편집" : "미리보기",
                    systemImage: note.isPreviewMode ? "pencil" : "eye"
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
        ToolbarItem(placement: .primaryAction) {
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                Image(systemName: "photo.badge.plus")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showExportSheet = true } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                note.isFavorited.toggle()
                note.saveDirty(in: context)
            } label: {
                Image(systemName: note.isFavorited ? "star.fill" : "star")
                    .foregroundStyle(note.isFavorited ? Color.yellow : .primary)
            }
        }
        #endif
    }

    // MARK: - 블록 삽입

    private func insertBlock(_ text: String) {
        let separator = localContent.isEmpty || localContent.hasSuffix("\n") ? "" : "\n"
        localContent += separator + text
        if !note.isPreviewMode { isEditorFocused = true }
    }

    private func applyStamp(preset: CategoryStampPreset?, folder: Folder?, toggleIfSame: Bool) {
        CategoryStampAssigner.apply(
            preset: preset,
            folder: folder,
            to: note,
            folders: allFolders,
            context: context,
            toggleIfSame: toggleIfSame
        )
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: - Auto-save (즉시 dirty, 0.3s 디스크 디바운스)

    private func scheduleAutoSave() {
        hasUnsavedChanges = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistNote()
        }
    }

    private func flushSaveIfNeeded() {
        guard hasUnsavedChanges || saveTask != nil else { return }
        saveTask?.cancel()
        saveTask = nil
        persistNote()
    }

    private func persistNote() {
        if note.content != localContent { note.content = localContent }
        note.updatedAt = Date()
        note.isDirty = true
        note.applyParsedTags(using: context)
        try? context.save()
        hasUnsavedChanges = false
        saveTask = nil
        SyncManager.shared.scheduleSync(context: context)
    }

    // MARK: - 이미지 첨부

    private func addAttachments(from items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            if let urlString = try? AttachmentManager.saveImage(data, for: note.id) {
                note.attachmentURLs.append(urlString)
            }
        }
        note.saveDirty(in: context)
        selectedPhotoItems = []
    }

    private func deleteAttachment(_ urlString: String) {
        AttachmentManager.deleteAttachment(urlString: urlString)
        note.attachmentURLs.removeAll { $0 == urlString }
        note.saveDirty(in: context)
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
            note.saveDirty(in: context)
            return
        }

        await locationManager.requestLocation()

        switch locationManager.status {
        case .ready:
            note.locationName = locationManager.locationName
            note.locationPOI = locationManager.locationPOI
            note.locationLat = locationManager.currentLocation?.coordinate.latitude
            note.locationLng = locationManager.currentLocation?.coordinate.longitude
            note.saveDirty(in: context)
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
                localContent += snippet
            }
        }
    }
}
#endif
