import SwiftUI
import SwiftData
import MapKit

// MARK: - NoteMapView

struct NoteMapView: View {
    @Binding var selectedNote: Note?
    @Query(sort: \Note.createdAt, order: .reverse) private var allNotes: [Note]
    @Query(sort: \Category.position) private var categories: [Category]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: UUID?
    @State private var sheetNote: Note?   // iOS 핀 탭 시 시트

    // 위치 정보가 있는 메모만
    private var locatedNotes: [Note] {
        allNotes.filter { !$0.isDeleted && $0.locationLat != nil && $0.locationLng != nil }
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mapBody
                .navigationTitle("지도")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $sheetNote) { note in
                    NavigationStack {
                        NoteEditorView(note: note)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("닫기") { sheetNote = nil }
                                }
                            }
                    }
                }
        }
        #else
        mapBody
            .navigationTitle("지도")
        #endif
    }

    @ViewBuilder
    private var mapBody: some View {
        if locatedNotes.isEmpty {
            emptyState
        } else {
            mapContent
                .onAppear { fitCamera() }
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        ContentUnavailableView(
            "위치 정보가 없습니다",
            systemImage: "map",
            description: Text("메모 작성 시 위치가 자동으로 기록됩니다.")
        )
    }

    // MARK: - 지도

    private var mapContent: some View {
        Map(position: $position) {
            ForEach(locatedNotes) { note in
                if let lat = note.locationLat, let lng = note.locationLng {
                    Annotation(
                        note.displayTitle.isEmpty ? "메모" : note.displayTitle,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    ) {
                        NoteMapPin(
                            color: category(for: note)?.color ?? Color.accentColor,
                            isSelected: selectedID == note.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.2)) {
                                selectedID = note.id
                            }
                            #if os(iOS)
                            sheetNote = note
                            #else
                            selectedNote = note
                            #endif
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
        // 선택된 메모 콜아웃 (macOS / iOS 공통 오버레이)
        .overlay(alignment: .bottom) {
            if let id = selectedID, let note = locatedNotes.first(where: { $0.id == id }) {
                NoteCallout(note: note, category: category(for: note)) {
                    #if os(iOS)
                    sheetNote = note
                    #else
                    selectedNote = note
                    #endif
                } onDismiss: {
                    withAnimation { selectedID = nil }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedID)
    }

    // MARK: - Helpers

    private func category(for note: Note) -> Category? {
        guard let catId = note.categoryId else { return nil }
        return categories.first { $0.id == catId }
    }

    private func fitCamera() {
        let coords = locatedNotes.compactMap { note -> CLLocationCoordinate2D? in
            guard let lat = note.locationLat, let lng = note.locationLng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coords.isEmpty else { return }

        if coords.count == 1 {
            position = .camera(MapCamera(centerCoordinate: coords[0], distance: 1000))
            return
        }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let latDelta = max((lats.max()! - lats.min()!) * 1.6, 0.01)
        let lngDelta = max((lngs.max()! - lngs.min()!) * 1.6, 0.01)
        position = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        ))
    }
}

// MARK: - iOS TabView 독립 사용

extension NoteMapView {
    init() {
        self._selectedNote = .constant(nil)
    }
}

// MARK: - 핀

struct NoteMapPin: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: color.opacity(0.45), radius: isSelected ? 8 : 3)

                Image(systemName: "note.text")
                    .font(.system(size: isSelected ? 18 : 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // 말풍선 꼬리
            PinTail()
                .fill(color)
                .frame(width: 12, height: 7)
        }
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 콜아웃 카드

struct NoteCallout: View {
    let note: Note
    let category: Category?
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 카테고리 색상 바
            if let cat = category {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cat.color)
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle.isEmpty ? "제목 없음" : note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                if let location = note.displayLocation {
                    Label(location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                onOpen()
            } label: {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}
