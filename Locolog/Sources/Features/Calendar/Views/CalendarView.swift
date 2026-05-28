import SwiftUI
import SwiftData

struct CalendarView: View {
    @Binding var selectedNote: Note?
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Category.position) private var categories: [Category]
    @State private var selectedDate: Date = Date()

    private var calendar = Calendar.current

    private var notesOnSelectedDate: [Note] {
        notes.filter { note in
            !note.isDeleted &&
            calendar.isDate(note.createdAt, inSameDayAs: selectedDate)
        }
    }

    private var noteCountByDate: [Date: Int] {
        Dictionary(grouping: notes.filter { !$0.isDeleted }, by: {
            calendar.startOfDay(for: $0.createdAt)
        }).mapValues(\.count)
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mainContent
                .navigationTitle("캘린더")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Note.self) { NoteEditorView(note: $0) }
        }
        #else
        mainContent
            .navigationTitle("캘린더")
        #endif
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            MonthCalendarView(
                selectedDate: $selectedDate,
                noteCountByDate: noteCountByDate
            )
            .padding()

            Divider()

            if notesOnSelectedDate.isEmpty {
                ContentUnavailableView(
                    "메모 없음",
                    systemImage: "note.text",
                    description: Text(selectedDate.formatted(date: .complete, time: .omitted))
                )
            } else {
                noteList
            }
        }
    }

    @ViewBuilder
    private var noteList: some View {
        #if os(iOS)
        List(notesOnSelectedDate) { note in
            NavigationLink(value: note) {
                NoteRowView(note: note, category: category(for: note))
            }
        }
        .listStyle(.plain)
        #else
        List(notesOnSelectedDate, selection: $selectedNote) { note in
            NoteRowView(note: note, category: category(for: note))
                .tag(note)
        }
        .listStyle(.plain)
        #endif
    }

    private func category(for note: Note) -> Category? {
        guard let catId = note.categoryId else { return nil }
        return categories.first { $0.id == catId }
    }
}

// 명시적 init 정의
extension CalendarView {
    init(selectedNote: Binding<Note?>) {
        self._selectedNote = selectedNote
    }

    // iOS TabView / 독립 사용 시
    init() {
        self._selectedNote = .constant(nil)
    }
}

// MARK: - 월간 히트맵 달력
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let noteCountByDate: [Date: Int]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay)
        let padding = Array(repeating: Date?.none, count: weekday - 1)
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
        return padding + days
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(selectedDate.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            noteCount: noteCountByDate[calendar.startOfDay(for: date)] ?? 0
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private func changeMonth(by value: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) else { return }
        selectedDate = newDate
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let noteCount: Int

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout)
                .foregroundStyle(isSelected ? Color.white : isToday ? Color.accentColor : Color.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(
                        isSelected ? Color.accentColor :
                        isToday ? Color.accentColor.opacity(0.15) : .clear
                    )
                )

            Circle()
                .fill(noteCount > 0 ? Color.accentColor.opacity(min(0.3 + Double(noteCount) * 0.15, 1.0)) : .clear)
                .frame(width: 4, height: 4)
        }
    }
}
