#if os(macOS)
import SwiftUI
import SwiftData

struct LocationPickerSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (String?, String?) -> Void

    @Query(sort: \Note.updatedAt, order: .reverse) private var recentNotes: [Note]
    @State private var manualName = ""

    private var recentLocations: [String] {
        var seen = Set<String>()
        return recentNotes
            .compactMap { $0.displayLocation }
            .filter { seen.insert($0).inserted }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("장소 입력")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("직접 입력")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("예: 강남 스타벅스, 서울 성동구", text: $manualName)
                    .textFieldStyle(.roundedBorder)
            }

            if !recentLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 장소")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(recentLocations, id: \.self) { location in
                        Button {
                            onSelect(location, nil)
                            isPresented = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(location)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            HStack {
                Button("건너뛰기") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("저장") {
                    let trimmed = manualName.trimmingCharacters(in: .whitespaces)
                    onSelect(trimmed.isEmpty ? nil : trimmed, nil)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .frame(minHeight: 200)
    }
}
#endif
