import SwiftUI
import SwiftData

struct SmartFolderFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.position) private var categories: [Category]
    @Query(sort: \SmartFolder.position) private var smartFolders: [SmartFolder]

    var editing: SmartFolder? = nil

    @State private var name = ""
    @State private var selectedCategoryId: UUID? = nil
    @State private var locationName = ""
    @State private var hasLocation = false
    @State private var tagInput = ""
    @State private var selectedTags: [String] = []
    @State private var hasDateFilter = false
    @State private var dateFrom = Calendar.current.startOfDay(for: Date())
    @State private var dateTo = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("스마트 폴더 이름", text: $name)
                }

                Section("필터 조건") {
                    // 카테고리
                    Picker("카테고리", selection: $selectedCategoryId) {
                        Text("전체").tag(UUID?.none)
                        ForEach(categories) { cat in
                            Label(cat.name, systemImage: "folder.fill")
                                .foregroundStyle(cat.color)
                                .tag(Optional(cat.id))
                        }
                    }

                    // 장소 텍스트
                    HStack {
                        Label("장소 이름", systemImage: "location")
                        Spacer()
                        TextField("예: 강남구", text: $locationName)
                            .multilineTextAlignment(.trailing)
                    }

                    // 위치 있는 메모만
                    Toggle(isOn: $hasLocation) {
                        Label("위치 기록된 메모만", systemImage: "location.fill")
                    }

                    // 태그
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("태그", systemImage: "tag")
                            Spacer()
                            TextField("태그 추가", text: $tagInput)
                                .multilineTextAlignment(.trailing)
                                .onSubmit { addTag() }
                            Button("추가") { addTag() }
                                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        if !selectedTags.isEmpty {
                            tagChips
                        }
                    }
                }

                // 날짜 범위
                Section {
                    Toggle(isOn: $hasDateFilter) {
                        Label("날짜 범위 지정", systemImage: "calendar")
                    }
                    if hasDateFilter {
                        DatePicker("시작일", selection: $dateFrom, displayedComponents: .date)
                        DatePicker("종료일", selection: $dateTo, in: dateFrom..., displayedComponents: .date)
                    }
                } header: {
                    Text("날짜")
                }

                // 미리보기
                if hasActiveFilter {
                    Section("미리보기") {
                        filterPreview
                    }
                }
            }
            .navigationTitle(editing == nil ? "새 스마트 폴더" : "스마트 폴더 편집")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - 태그 칩

    private var tagChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(selectedTags, id: \.self) { tag in
                HStack(spacing: 3) {
                    Text("#\(tag)")
                        .font(.caption)
                    Button {
                        selectedTags.removeAll { $0 == tag }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - 필터 미리보기

    private var filterPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let catId = selectedCategoryId,
               let cat = categories.first(where: { $0.id == catId }) {
                Label(cat.name, systemImage: "folder.fill").foregroundStyle(cat.color)
            }
            if !locationName.isEmpty {
                Label(locationName, systemImage: "location")
            }
            if hasLocation {
                Label("위치 기록 있음", systemImage: "location.fill")
            }
            if !selectedTags.isEmpty {
                Label(selectedTags.map { "#\($0)" }.joined(separator: " "), systemImage: "tag")
            }
            if hasDateFilter {
                Label(
                    "\(dateFrom.formatted(date: .abbreviated, time: .omitted)) ~ \(dateTo.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
            }
        }
        .font(.caption)
    }

    private var hasActiveFilter: Bool {
        selectedCategoryId != nil || !locationName.isEmpty || hasLocation ||
        !selectedTags.isEmpty || hasDateFilter
    }

    // MARK: - 액션

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        tagInput = ""
    }

    private func loadExisting() {
        guard let sf = editing else { return }
        name = sf.name
        let f = sf.filter
        selectedCategoryId = f.categoryId
        locationName = f.locationName ?? ""
        hasLocation = f.hasLocation ?? false
        selectedTags = f.tagNames
        if let from = f.dateFrom, let to = f.dateTo {
            hasDateFilter = true
            dateFrom = from
            dateTo = to
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var filter = NoteFilter()
        filter.categoryId   = selectedCategoryId
        filter.locationName = locationName.isEmpty ? nil : locationName
        filter.hasLocation  = hasLocation ? true : nil
        filter.tagNames     = selectedTags
        filter.dateFrom     = hasDateFilter ? dateFrom : nil
        filter.dateTo       = hasDateFilter ? dateTo : nil

        let json = (try? JSONEncoder().encode(filter))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        if let sf = editing {
            sf.name = trimmed
            sf.filterJSON = json
        } else {
            context.insert(SmartFolder(name: trimmed, filter: filter, position: smartFolders.count))
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - FlowLayout (태그 칩 줄바꿈)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { row in row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? 0
        var rows: [[LayoutSubviews.Element]] = [[]]
        var rowWidth: CGFloat = 0

        for view in subviews {
            let width = view.sizeThatFits(.unspecified).width
            if rowWidth + width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(view)
            rowWidth += width + spacing
        }
        return rows
    }
}
