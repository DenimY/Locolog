import Foundation
import SwiftData
import Supabase

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?

    private var syncTask: Task<Void, Never>?

    // MARK: - Public API

    /// 전체 동기화 (push → pull) — 앱 시작 / 포그라운드 복귀 시
    func sync(context: ModelContext) async {
        guard AuthManager.shared.isSignedIn, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        await push(context: context)
        await pull(context: context)
        lastSyncedAt = Date()
    }

    /// 메모 편집 후 2초 디바운스 push — NoteEditorView autosave에서 호출
    func scheduleSync(context: ModelContext) {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await push(context: context)
        }
    }

    // MARK: - Push (로컬 → Supabase)

    private func push(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.isDirty })
        guard let dirtyNotes = try? context.fetch(descriptor), !dirtyNotes.isEmpty else { return }

        let payloads = dirtyNotes.map { NotePayload(from: $0, userId: userId) }
        do {
            try await supabase.from("notes").upsert(payloads).execute()
            dirtyNotes.forEach { $0.isDirty = false }
            try? context.save()
        } catch {
            // isDirty 유지 → 다음 sync 때 재시도
        }
    }

    // MARK: - Pull (Supabase → 로컬)

    private func pull(context: ModelContext) async {
        do {
            let records: [NoteRecord] = try await supabase
                .from("notes")
                .select()
                .execute()
                .value

            let allDescriptor = FetchDescriptor<Note>()
            let localNotes = (try? context.fetch(allDescriptor)) ?? []
            let localById = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

            for record in records {
                if let local = localById[record.id] {
                    // 서버가 더 최신이고 로컬 미전송 변경이 없을 때만 덮어쓰기
                    if record.updatedAt > local.updatedAt && !local.isDirty {
                        local.content      = record.content
                        local.categoryId   = record.categoryId
                        local.updatedAt    = record.updatedAt
                        local.locationLat  = record.locationLat
                        local.locationLng  = record.locationLng
                        local.locationName = record.locationName
                        local.locationPOI  = record.locationPoi
                        local.reminderAt   = record.reminderAt
                        local.isDeleted    = record.isDeleted
                        local.isDirty      = false
                    }
                } else {
                    // 서버에만 있는 메모 → 로컬에 삽입
                    let note = Note(content: record.content, categoryId: record.categoryId)
                    note.id           = record.id
                    note.createdAt    = record.createdAt
                    note.updatedAt    = record.updatedAt
                    note.locationLat  = record.locationLat
                    note.locationLng  = record.locationLng
                    note.locationName = record.locationName
                    note.locationPOI  = record.locationPoi
                    note.reminderAt   = record.reminderAt
                    note.isDeleted    = record.isDeleted
                    note.isDirty      = false
                    context.insert(note)
                }
            }
            try? context.save()
        } catch {
            // pull 실패 시 로컬 데이터 유지
        }
    }
}

// MARK: - Supabase 페이로드

private struct NotePayload: Encodable {
    let id: UUID
    let userId: UUID
    let content: String
    let categoryId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let locationLat: Double?
    let locationLng: Double?
    let locationName: String?
    let locationPoi: String?
    let reminderAt: Date?
    let isDeleted: Bool
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case content
        case categoryId   = "category_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case locationLat  = "location_lat"
        case locationLng  = "location_lng"
        case locationName = "location_name"
        case locationPoi  = "location_poi"
        case reminderAt   = "reminder_at"
        case isDeleted    = "is_deleted"
        case isPublic     = "is_public"
    }

    init(from note: Note, userId: UUID) {
        self.id           = note.id
        self.userId       = userId
        self.content      = note.content
        self.categoryId   = note.categoryId
        self.createdAt    = note.createdAt
        self.updatedAt    = note.updatedAt
        self.locationLat  = note.locationLat
        self.locationLng  = note.locationLng
        self.locationName = note.locationName
        self.locationPoi  = note.locationPOI
        self.reminderAt   = note.reminderAt
        self.isDeleted    = note.isDeleted
        self.isPublic     = false
    }
}

private struct NoteRecord: Decodable {
    let id: UUID
    let content: String
    let categoryId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let locationLat: Double?
    let locationLng: Double?
    let locationName: String?
    let locationPoi: String?
    let reminderAt: Date?
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case categoryId   = "category_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case locationLat  = "location_lat"
        case locationLng  = "location_lng"
        case locationName = "location_name"
        case locationPoi  = "location_poi"
        case reminderAt   = "reminder_at"
        case isDeleted    = "is_deleted"
    }
}
