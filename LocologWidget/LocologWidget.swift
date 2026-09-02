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

// MARK: - Small Widget (탭해서 새 메모)

struct SmallWidgetView: View {
    let entry: LocologEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text("Locolog")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 8)

            Spacer()

            Text("탭해서 적기")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if let note = entry.notes.first {
                Text(note.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 6)
            } else {
                Text("날짜와 장소로 모입니다")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "locolog://new"))
    }
}

// MARK: - Medium Widget (새 메모 + 최근 3개)

struct MediumWidgetView: View {
    let entry: LocologEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("Locolog")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Link(destination: URL(string: "locolog://new")!) {
                    Text("새 메모")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Divider()

            if entry.notes.isEmpty {
                Spacer()
                Link(destination: URL(string: "locolog://new")!) {
                    HStack {
                        Spacer()
                        Text("탭해서 적기")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
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
        .widgetURL(URL(string: "locolog://new"))
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
        .configurationDisplayName("Locolog")
        .description("탭하면 바로 새 메모를 던집니다. 중형은 최근 메모도 엽니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
