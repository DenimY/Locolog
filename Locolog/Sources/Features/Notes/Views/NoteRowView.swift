import SwiftUI

struct NoteRowView: View {
    let note: Note
    var category: Category? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let cat = category {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(cat.color)
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle)
                    .font(AppTheme.listTitleFont)
                    .lineLimit(1)

                if !note.displayPreview.isEmpty {
                    Text(note.displayPreview)
                        .font(AppTheme.listMetaFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                let tagNames = note.parsedTagNames
                if !tagNames.isEmpty {
                    tagChips(tagNames)
                }

                HStack(spacing: 6) {
                    if let location = note.displayLocation {
                        Label(location, systemImage: "location.fill")
                            .font(AppTheme.listMetaFont)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                        .font(AppTheme.listMetaFont)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, AppTheme.listRowVPadding)
    }

    @ViewBuilder
    private func tagChips(_ tags: [String]) -> some View {
        let visible = Array(tags.prefix(3))
        let overflow = tags.count - visible.count
        HStack(spacing: 4) {
            ForEach(visible, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
