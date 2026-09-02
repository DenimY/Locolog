#if os(macOS)
import SwiftUI
import SwiftData

struct NoteDetailPanel: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Query private var allFolders: [Folder]
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showEditor = false

    private var category: Folder? {
        guard let id = note.folderId else { return nil }
        return allFolders.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                noteCard
                    .padding(.bottom, 20)

                if note.displayLocation != nil || note.locationLat != nil {
                    locationRow
                    Divider().padding(.vertical, 16)
                }

                actionButtons
                    .padding(.bottom, 20)

                Divider().padding(.bottom, 16)

                contentSection
                    .padding(.bottom, 16)

                if !note.parsedTagNames.isEmpty {
                    tagsSection
                        .padding(.bottom, 16)
                }

                if !note.attachmentURLs.isEmpty {
                    Divider().padding(.bottom, 16)
                    attachmentsSection
                        .padding(.bottom, 16)
                }

                Divider().padding(.bottom, 16)
                creationInfo
            }
            .padding(20)
        }
        .navigationTitle("장소 메모")
        .sheet(isPresented: $showEditor) {
            NavigationStack { NoteEditorView(note: note) }
                .frame(minWidth: 620, minHeight: 520)
        }
    }

    // MARK: - 노트 카드 (상단 썸네일)

    private var noteCard: some View {
        HStack(spacing: 14) {
            // 컬러 썸네일
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(category?.colorHex != nil ? category!.color : Color.accentColor)
                    .frame(width: 56, height: 56)
                Image(systemName: "note.text")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle.isEmpty ? "제목 없음" : note.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                Text(note.createdAt.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let cat = category {
                    Label(cat.name, systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(cat.colorHex != nil ? cat.color : .secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - 위치

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let poi = note.locationPOI {
                Text(poi)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            if let name = note.locationName {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if note.locationLat != nil {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 액션 버튼

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // 편집 (primary)
            Button {
                showEditor = true
            } label: {
                Label("편집", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            // 즐겨찾기
            Button {
                note.isFavorited.toggle()
                note.saveDirty(in: context)
            } label: {
                Image(systemName: note.isFavorited ? "star.fill" : "star")
                    .foregroundStyle(note.isFavorited ? .yellow : .secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .help(note.isFavorited ? "즐겨찾기 해제" : "즐겨찾기 추가")

            // 공유
            ShareLink(item: note.content,
                      subject: Text(note.displayTitle),
                      message: Text(note.content)) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .help("공유")
        }
    }

    // MARK: - 메모 내용

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("메모", systemImage: "doc.text")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("내용 없음")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                // 내용 미리보기 (앞 400자)
                Text(String(note.content.prefix(400)))
                    .font(.callout)
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - 태그

    private var tagsSection: some View {
        FlowLayout(spacing: 6) {
            ForEach(note.parsedTagNames, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.1)))
            }
        }
    }

    // MARK: - 첨부 파일

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("첨부 파일", systemImage: "paperclip")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(note.attachmentURLs, id: \.self) { urlString in
                if let url = URL(string: urlString), url.isFileURL {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.accentColor)
                        Text(url.lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
                }
            }
        }
    }

    // MARK: - 생성 정보

    private var creationInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("생성 정보", systemImage: "info.circle")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                // 아바타
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.callout)
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    if case .signedIn(_, let email) = authManager.authState, let email {
                        Text(email)
                            .font(.callout)
                            .fontWeight(.medium)
                    } else {
                        Text("로컬 사용자")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - FlowLayout (태그 칩 줄바꿈)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in
            row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxW = proposal.width ?? 0
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowW: CGFloat = 0
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if rowW + w > maxW && !rows[rows.count - 1].isEmpty {
                rows.append([]); rowW = 0
            }
            rows[rows.count - 1].append(view)
            rowW += w + spacing
        }
        return rows
    }
}

// MARK: - 휴지통 뷰

struct TrashView: View {
    @Binding var selectedNote: Note?
    @Query(filter: #Predicate<Note> { $0.isDeleted },
           sort: \Note.updatedAt, order: .reverse) private var deletedNotes: [Note]
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if deletedNotes.isEmpty {
                ContentUnavailableView("휴지통이 비어 있습니다",
                                       systemImage: "trash",
                                       description: Text("삭제된 메모가 없습니다."))
            } else {
                List(deletedNotes, selection: $selectedNote) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.displayTitle.isEmpty ? "제목 없음" : note.displayTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(note)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { permanentlyDelete(note) } label: {
                            Label("완전 삭제", systemImage: "trash.slash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { restore(note) } label: {
                            Label("복구", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .contextMenu {
                        Button { restore(note) } label: {
                            Label("복구", systemImage: "arrow.uturn.backward")
                        }
                        Button(role: .destructive) { permanentlyDelete(note) } label: {
                            Label("완전 삭제", systemImage: "trash.slash")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("휴지통")
        .toolbar {
            if !deletedNotes.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button("모두 삭제", role: .destructive) { emptyTrash() }
                }
            }
        }
    }

    private func restore(_ note: Note) {
        note.isDeleted = false
        note.saveDirty(in: context)
        if selectedNote?.id == note.id { selectedNote = nil }
    }

    private func permanentlyDelete(_ note: Note) {
        AttachmentManager.deleteAll(for: note.id)
        IconManager.deleteIcon(urlString: note.iconImagePath)
        if selectedNote?.id == note.id { selectedNote = nil }
        SyncManager.shared.enqueueDeletedNote(note.id)
        context.delete(note)
        SyncManager.shared.saveAndSync(context: context)
    }

    private func emptyTrash() {
        deletedNotes.forEach {
            AttachmentManager.deleteAll(for: $0.id)
            IconManager.deleteIcon(urlString: $0.iconImagePath)
            SyncManager.shared.enqueueDeletedNote($0.id)
            context.delete($0)
        }
        selectedNote = nil
        SyncManager.shared.saveAndSync(context: context)
    }
}
#endif
