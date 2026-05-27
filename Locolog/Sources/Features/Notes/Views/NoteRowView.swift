import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
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
        .padding(.vertical, AppTheme.listRowVPadding)
    }
}
