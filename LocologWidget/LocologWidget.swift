import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct LocologEntry: TimelineEntry {
    let date: Date
    let notes: [WidgetNote]
}

// MARK: - Provider

struct LocologProvider: TimelineProvider {
    func placeholder(in context: Context) -> LocologEntry {
        LocologEntry(date: Date(), notes: [
            WidgetNote(
                id: "preview",
                title: "오늘의 회의 메모",
                preview: "주요 안건을 정리했습니다.",
                locationName: "서울 성동구",
                createdAt: Date()
            )
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (LocologEntry) -> Void) {
        completion(LocologEntry(date: Date(), notes: WidgetNote.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LocologEntry>) -> Void) {
        let entry = LocologEntry(date: Date(), notes: WidgetNote.load())
        let next  = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Entry View (family 분기)

struct LocologWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LocologEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (최신 메모 1개)

struct SmallWidgetView: View {
    let entry: LocologEntry

    var body: some View {
        if let note = entry.notes.first {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("최근 메모")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.bottom, 8)

                Spacer()

                // 메모 제목
                Text(note.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                Spacer()

                // 하단 메타
                VStack(alignment: .leading, spacing: 3) {
                    if let loc = note.locationName {
                        Label(loc, systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "locolog://note/\(note.id)"))
        } else {
            emptySmallView
        }
    }

    private var emptySmallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("메모 없음")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "locolog://open"))
    }
}

// MARK: - Medium Widget (최근 메모 3개)

struct MediumWidgetView: View {
    let entry: LocologEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("최근 메모")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            if entry.notes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("작성된 메모가 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.notes.prefix(3).enumerated()), id: \.element.id) { index, note in
                    Link(destination: URL(string: "locolog://note/\(note.id)")!) {
                        NoteRowWidget(note: note)
                    }
                    if index < min(entry.notes.count, 3) - 1 {
                        Divider()
                    }
                }
                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct NoteRowWidget: View {
    let note: WidgetNote

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let loc = note.locationName {
                        Label(loc, systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(note.createdAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Configuration

struct LocologWidget: Widget {
    let kind = "LocologWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LocologProvider()) { entry in
            LocologWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Locolog 메모")
        .description("최근 메모를 홈 화면에서 빠르게 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
