#if os(macOS)
import SwiftUI
import SwiftData
import MapKit

enum CalendarDisplayMode: String, CaseIterable {
    case day   = "일"
    case week  = "주"
    case month = "월"
}

struct MapCalendarView: View {
    @Binding var selectedNote: Note?
    @Environment(\.locale) private var locale

    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @Query private var allFolders: [Folder]

    @State private var selectedDate: Date = Date()
    @State private var displayMonth: Date = Date()
    @State private var displayMode: CalendarDisplayMode = .month
    @State private var mapPosition: MapCameraPosition = .automatic

    // 삭제되지 않고 위치 있는 메모
    private var locatedNotes: [Note] {
        allNotes.filter { !$0.isDeleted && $0.locationLat != nil && $0.locationLng != nil }
    }

    // 선택된 날짜의 메모
    private var selectedDayNotes: [Note] {
        allNotes.filter {
            !$0.isDeleted &&
            Calendar.current.isDate($0.createdAt, inSameDayAs: selectedDate)
        }
    }

    // 선택된 날짜에 메모 있는 날의 맵 핀 (선택일 강조)
    private var highlightedNotes: [Note] {
        selectedDayNotes.filter { $0.locationLat != nil }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                calendarToolbar
                Divider()
                // 지도 (상단 45%)
                mapSection
                    .frame(height: geo.size.height * 0.45)
                    .clipped()
                Divider()
                // 캘린더 그리드 (하단 55%)
                calendarSection
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("캘린더")
    }

    // MARK: - 툴바

    private var calendarToolbar: some View {
        HStack(spacing: 12) {
            // 오늘 버튼
            Button("오늘") {
                withAnimation { displayMonth = Date(); selectedDate = Date() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 이전/다음 달
            HStack(spacing: 4) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.callout)
                }
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.callout)
                }
            }
            .buttonStyle(.plain)

            // 월 표시
            Text(monthTitle)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            // 일/주/월 전환
            Picker("보기", selection: $displayMode) {
                ForEach(CalendarDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: displayMonth)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(
            byAdding: .month, value: delta, to: displayMonth
        ) else { return }
        withAnimation { displayMonth = next }
    }

    // MARK: - 지도

    private var mapSection: some View {
        Map(position: $mapPosition) {
            ForEach(locatedNotes) { note in
                if let lat = note.locationLat, let lng = note.locationLng {
                    Annotation(
                        note.displayTitle.isEmpty ? "메모" : note.displayTitle,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    ) {
                        let isHighlighted = highlightedNotes.contains { $0.id == note.id }
                        NoteMapPin(
                            color: categoryColor(for: note),
                            isSelected: selectedNote?.id == note.id || isHighlighted
                        )
                        .onTapGesture {
                            selectedNote = note
                            selectedDate = note.createdAt
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }

    // MARK: - 캘린더 그리드

    private var calendarSection: some View {
        VStack(spacing: 0) {
            // 요일 헤더
            weekdayHeader

            Divider()

            // 날짜 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            notes: notes(on: date),
                            folders: allFolders
                        ) {
                            selectedDate = date
                            // 그날 노트가 하나면 바로 선택
                            let dayNotes = notes(on: date).filter { !$0.isDeleted }
                            if dayNotes.count == 1 { selectedNote = dayNotes.first }
                        }
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                Text(LocalizedStringKey(day))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(day == "일" ? .red : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 날짜 계산

    private var monthDays: [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1  // 일요일 시작

        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayMonth)
        ) else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                days.append(date)
            }
        }
        // 마지막 주 채우기
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func notes(on date: Date) -> [Note] {
        allNotes.filter {
            !$0.isDeleted &&
            Calendar.current.isDate($0.createdAt, inSameDayAs: date)
        }
    }

    private func categoryColor(for note: Note) -> Color {
        guard let folderId = note.folderId,
              let folder = allFolders.first(where: { $0.id == folderId }),
              folder.colorHex != nil else {
            return Color.accentColor
        }
        return folder.color
    }
}

// MARK: - 날짜 셀

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let notes: [Note]
    let folders: [Folder]
    let onTap: () -> Void

    private var isWeekend: Bool {
        Calendar.current.component(.weekday, from: date) == 1
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                // 날짜 숫자
                HStack {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.callout)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .white : isWeekend ? .red : .primary)
                        .frame(width: 24, height: 24)
                        .background {
                            if isToday {
                                Circle().fill(Color.accentColor)
                            } else if isSelected {
                                Circle().fill(Color.accentColor.opacity(0.15))
                            }
                        }
                    Spacer()
                }

                // 메모 미리보기 (최대 2개)
                ForEach(notes.prefix(2)) { note in
                    noteChip(note)
                }

                if notes.count > 2 {
                    Text("+\(notes.count - 2)개")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isSelected && !isToday ? Color.accentColor.opacity(0.06) : Color.clear)
            .overlay(alignment: .topLeading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func noteChip(_ note: Note) -> some View {
        let color: Color = {
            guard let folderId = note.folderId,
                  let folder = folders.first(where: { $0.id == folderId }),
                  folder.colorHex != nil else {
                return .accentColor
            }
            return folder.color
        }()

        return HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3)
            Text(note.displayTitle.isEmpty ? "메모" : note.displayTitle)
                .font(.system(size: 10))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.12)))
    }
}
#endif
