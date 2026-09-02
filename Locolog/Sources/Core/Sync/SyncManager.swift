import Foundation
import SwiftData
import Supabase
import Network
import OSLog

/// 푸시 직후 dirty 해제 여부 판단 — 전송 중 로컬이 더 바뀌면 dirty를 유지한다.
struct NotePushSnapshot: Equatable {
    let id: UUID
    let updatedAt: Date
    let content: String
    let folderId: UUID?
    let categoryId: UUID?
    let isFavorited: Bool
    let isDeleted: Bool
    let noteTypeRaw: String
    let locationName: String?
    let locationPOI: String?
    let reminderAt: Date?
    let iconEmoji: String?

    init(note: Note) {
        self.id           = note.id
        self.updatedAt    = note.updatedAt
        self.content      = note.content
        self.folderId     = note.folderId
        self.categoryId   = note.categoryId
        self.isFavorited  = note.isFavorited
        self.isDeleted    = note.isDeleted
        self.noteTypeRaw  = note.noteTypeRaw
        self.locationName = note.locationName
        self.locationPOI  = note.locationPOI
        self.reminderAt   = note.reminderAt
        self.iconEmoji    = note.iconEmoji
    }

    func matches(_ note: Note) -> Bool {
        id == note.id
            && updatedAt == note.updatedAt
            && content == note.content
            && folderId == note.folderId
            && categoryId == note.categoryId
            && isFavorited == note.isFavorited
            && isDeleted == note.isDeleted
            && noteTypeRaw == note.noteTypeRaw
            && locationName == note.locationName
            && locationPOI == note.locationPOI
            && reminderAt == note.reminderAt
            && iconEmoji == note.iconEmoji
    }
}

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isOnline = true

    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?
    private var pendingFullSync = false
    private var pendingPush = false
    private var lastOwnPushAt: Date?

    private var pathMonitor: NWPathMonitor?
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var remotePullTask: Task<Void, Never>?

    private let log = Logger(subsystem: "com.locolog.app", category: "sync")
    private let defaults = UserDefaults.standard
    private let deletedNotesKey = "sync.pendingDeletedNoteIds"
    private let deletedFoldersKey = "sync.pendingDeletedFolderIds"
    private let deletedSmartFoldersKey = "sync.pendingDeletedSmartFolderIds"

    // MARK: - Lifecycle

    func attach(context: ModelContext) {
        modelContext = context
        startNetworkMonitorIfNeeded()
    }

    func start(context: ModelContext) async {
        attach(context: context)
        await sync(context: context)
        await startRealtime()
    }

    func stop() {
        syncTask?.cancel()
        remotePullTask?.cancel()
        realtimeTask?.cancel()
        Task { await stopRealtime() }
    }

    func syncUsingStoredContext() async {
        guard let context = modelContext else { return }
        await sync(context: context)
    }

    // MARK: - Public API

    /// 전체 동기화 (push → pull) — 앱 시작 / 포그라운드 복귀 / 로그인 / 수동
    func sync(context: ModelContext) async {
        guard AuthManager.shared.isSignedIn else { return }
        modelContext = context
        if isSyncing {
            pendingFullSync = true
            return
        }
        isSyncing = true
        lastError = nil

        await processPendingHardDeletes()
        await push(context: context)
        await pull(context: context)
        rescheduleReminders(context: context)

        if lastError == nil {
            lastSyncedAt = Date()
        }
        isSyncing = false
        await drainPendingWork(context: context)
    }

    /// 로컬 변경 후 2초 디바운스 push — pull은 하지 않음
    func scheduleSync(context: ModelContext) {
        guard AuthManager.shared.isSignedIn else { return }
        modelContext = context
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await self?.pushNow(context: context)
        }
    }

    func saveAndSync(context: ModelContext) {
        try? context.save()
        scheduleSync(context: context)
    }

    func enqueueDeletedNote(_ id: UUID) {
        appendPendingId(id, key: deletedNotesKey)
    }

    func enqueueDeletedFolder(_ id: UUID) {
        appendPendingId(id, key: deletedFoldersKey)
    }

    func enqueueDeletedSmartFolder(_ id: UUID) {
        appendPendingId(id, key: deletedSmartFoldersKey)
    }

    // MARK: - Queue

    private func pushNow(context: ModelContext) async {
        guard AuthManager.shared.isSignedIn else { return }
        if isSyncing {
            pendingPush = true
            return
        }
        isSyncing = true
        await processPendingHardDeletes()
        await push(context: context)
        isSyncing = false
        await drainPendingWork(context: context)
    }

    private func drainPendingWork(context: ModelContext) async {
        if pendingFullSync {
            pendingFullSync = false
            pendingPush = false
            await sync(context: context)
        } else if pendingPush {
            pendingPush = false
            await pushNow(context: context)
        }
    }

    // MARK: - Push

    private func push(context: ModelContext) async {
        guard supabase.auth.currentUser?.id != nil else { return }
        await pushFolders(context: context)
        await pushSmartFolders(context: context)
        await pushNotes(context: context)
        lastOwnPushAt = Date()
    }

    private func pushNotes(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.isDirty })
        guard let dirtyNotes = try? context.fetch(descriptor), !dirtyNotes.isEmpty else { return }

        let snapshots = dirtyNotes.map { NotePushSnapshot(note: $0) }
        let payloads = dirtyNotes.map { NotePayload(from: $0, userId: userId) }

        do {
            try await upsertNotes(payloads)
            lastError = nil
            clearDirtyIfUnchanged(dirtyNotes, snapshots: snapshots, context: context)
        } catch {
            log.error("notes upsert failed: \(error.localizedDescription, privacy: .public)")
            do {
                let legacy = dirtyNotes.map { NotePayloadLegacy(from: $0, userId: userId) }
                try await supabase.from("notes").upsert(legacy, onConflict: "id").execute()
                lastError = "서버 스키마가 오래되어 폴더·노트 타입은 동기화되지 않았습니다."
                clearDirtyIfUnchanged(dirtyNotes, snapshots: snapshots, context: context)
            } catch {
                lastError = error.localizedDescription
                log.error("notes legacy upsert failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func upsertNotes(_ payloads: [NotePayload]) async throws {
        try await supabase.from("notes").upsert(payloads, onConflict: "id").execute()
    }

    private func clearDirtyIfUnchanged(_ notes: [Note], snapshots: [NotePushSnapshot], context: ModelContext) {
        let byId = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for note in notes {
            guard let snap = byId[note.id], snap.matches(note) else { continue }
            note.isDirty = false
        }
        try? context.save()
    }

    private func pushFolders(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        let folders = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
        guard !folders.isEmpty else { return }
        let payloads = folders.map { FolderPayload(from: $0, userId: userId) }
        do {
            try await supabase.from("folders").upsert(payloads, onConflict: "id").execute()
        } catch {
            log.error("folders upsert failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pushSmartFolders(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        let folders = (try? context.fetch(FetchDescriptor<SmartFolder>())) ?? []
        guard !folders.isEmpty else { return }
        let payloads = folders.map { SmartFolderPayload(from: $0, userId: userId) }
        do {
            try await supabase.from("smart_folders").upsert(payloads, onConflict: "id").execute()
        } catch {
            log.error("smart_folders upsert failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pull

    private func pull(context: ModelContext) async {
        guard supabase.auth.currentUser?.id != nil else { return }
        await pullFolders(context: context)
        await pullSmartFolders(context: context)
        await pullNotes(context: context)
    }

    private func rescheduleReminders(context: ModelContext) {
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        NotificationManager.shared.rescheduleAll(notes: notes)
    }

    private func pullNotes(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let records: [NoteRecord] = try await supabase
                .from("notes")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let localNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
            let localById = Dictionary(localNotes.map { ($0.id, $0) }, uniquingKeysWith: { a, b in
                a.updatedAt >= b.updatedAt ? a : b
            })
            let pendingHardDelete = Set(pendingIds(key: deletedNotesKey))

            for record in records {
                if pendingHardDelete.contains(record.id) { continue }
                if let local = localById[record.id] {
                    if record.updatedAt > local.updatedAt && !local.isDirty {
                        apply(record, to: local)
                        local.applyParsedTags(using: context)
                    }
                } else {
                    let note = Note(content: record.content, categoryId: record.categoryId)
                    note.id = record.id
                    note.createdAt = record.createdAt
                    apply(record, to: note)
                    context.insert(note)
                    note.applyParsedTags(using: context)
                }
            }
            try? context.save()
        } catch {
            lastError = error.localizedDescription
            log.error("notes pull failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func apply(_ record: NoteRecord, to note: Note) {
        note.content      = record.content
        note.categoryId   = record.categoryId
        note.folderId     = record.folderId ?? record.categoryId
        note.updatedAt    = record.updatedAt
        note.locationLat  = record.locationLat
        note.locationLng  = record.locationLng
        note.locationName = record.locationName
        note.locationPOI  = record.locationPoi
        note.reminderAt   = record.reminderAt
        note.isDeleted    = record.isDeleted
        note.isFavorited  = record.isFavorited ?? note.isFavorited
        if let type = record.noteType, !type.isEmpty {
            note.noteTypeRaw = type
        }
        if record.iconEmoji != nil {
            note.iconEmoji = record.iconEmoji
        }
        note.isDirty = false
    }

    private func pullFolders(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let records: [FolderRecord] = try await supabase
                .from("folders")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let locals = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
            let localById = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let pendingDelete = Set(pendingIds(key: deletedFoldersKey))

            for record in records {
                if pendingDelete.contains(record.id) { continue }
                if let local = localById[record.id] {
                    local.name = record.name
                    local.parentId = record.parentId
                    local.position = record.position
                    local.colorHex = record.colorHex
                    local.iconEmoji = record.iconEmoji ?? local.iconEmoji
                } else {
                    let folder = Folder(
                        name: record.name,
                        parentId: record.parentId,
                        position: record.position,
                        colorHex: record.colorHex
                    )
                    folder.id = record.id
                    folder.iconEmoji = record.iconEmoji
                    context.insert(folder)
                }
            }

            try? context.save()
        } catch {
            log.error("folders pull failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pullSmartFolders(context: ModelContext) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let records: [SmartFolderRecord] = try await supabase
                .from("smart_folders")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let locals = (try? context.fetch(FetchDescriptor<SmartFolder>())) ?? []
            let localById = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let pendingDelete = Set(pendingIds(key: deletedSmartFoldersKey))

            for record in records {
                if pendingDelete.contains(record.id) { continue }
                if let local = localById[record.id] {
                    local.name = record.name
                    local.filterJSON = record.filterJSON
                    local.position = record.position
                } else {
                    var filter = NoteFilter()
                    if let data = record.filterJSON.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(NoteFilter.self, from: data) {
                        filter = decoded
                    }
                    let folder = SmartFolder(name: record.name, filter: filter, position: record.position)
                    folder.id = record.id
                    folder.filterJSON = record.filterJSON
                    context.insert(folder)
                }
            }
            try? context.save()
        } catch {
            log.error("smart_folders pull failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Hard deletes

    private func processPendingHardDeletes() async {
        guard supabase.auth.currentUser != nil else { return }

        await deleteRemoteIds(pendingIds(key: deletedNotesKey), table: "notes", defaultsKey: deletedNotesKey)
        await deleteRemoteIds(pendingIds(key: deletedFoldersKey), table: "folders", defaultsKey: deletedFoldersKey)
        await deleteRemoteIds(pendingIds(key: deletedSmartFoldersKey), table: "smart_folders", defaultsKey: deletedSmartFoldersKey)
    }

    private func deleteRemoteIds(_ ids: [UUID], table: String, defaultsKey: String) async {
        guard !ids.isEmpty else { return }
        var remaining: [UUID] = []
        for id in ids {
            do {
                try await supabase.from(table).delete().eq("id", value: id).execute()
            } catch {
                remaining.append(id)
                log.error("delete \(table) \(id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        defaults.set(remaining.map(\.uuidString), forKey: defaultsKey)
    }

    private func appendPendingId(_ id: UUID, key: String) {
        var ids = pendingIds(key: key)
        if !ids.contains(id) { ids.append(id) }
        defaults.set(ids.map(\.uuidString), forKey: key)
    }

    private func pendingIds(key: String) -> [UUID] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:))
    }

    // MARK: - Network

    private func startNetworkMonitorIfNeeded() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in
                SyncManager.shared.handlePathChange(isOnline: online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.locolog.network"))
    }

    private func handlePathChange(isOnline: Bool) {
        let wasOffline = !self.isOnline
        self.isOnline = isOnline
        if isOnline && wasOffline, AuthManager.shared.isSignedIn, let context = modelContext {
            Task { await sync(context: context) }
        }
    }

    // MARK: - Realtime

    private func startRealtime() async {
        await stopRealtime()
        guard let userId = supabase.auth.currentUser?.id else { return }

        let channel = supabase.channel("locolog-sync-\(userId.uuidString)")
        let noteStream = channel.postgresChange(AnyAction.self, table: "notes")
        await channel.subscribe()
        realtimeChannel = channel

        realtimeTask = Task { @MainActor [weak self] in
            for await _ in noteStream {
                await self?.handleRemoteChange()
            }
        }
    }

    private func stopRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            await supabase.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    private func handleRemoteChange() async {
        if let last = lastOwnPushAt, Date().timeIntervalSince(last) < 1.5 { return }
        remotePullTask?.cancel()
        remotePullTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            guard let self, let context = self.modelContext else { return }
            if self.isSyncing {
                self.pendingFullSync = true
                return
            }
            await self.pull(context: context)
        }
    }
}

// MARK: - Note persistence helper

extension Note {
    @MainActor
    func saveDirty(in context: ModelContext) {
        markDirty()
        SyncManager.shared.saveAndSync(context: context)
    }
}

// MARK: - Payloads

private struct NotePayload: Encodable {
    let id: UUID
    let userId: UUID
    let content: String
    let categoryId: UUID?
    let folderId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let locationLat: Double?
    let locationLng: Double?
    let locationName: String?
    let locationPoi: String?
    let reminderAt: Date?
    let isDeleted: Bool
    let isFavorited: Bool
    let isPublic: Bool
    let noteType: String
    let iconEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId       = "user_id"
        case content
        case categoryId   = "category_id"
        case folderId     = "folder_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case locationLat  = "location_lat"
        case locationLng  = "location_lng"
        case locationName = "location_name"
        case locationPoi  = "location_poi"
        case reminderAt   = "reminder_at"
        case isDeleted    = "is_deleted"
        case isFavorited  = "is_favorited"
        case isPublic     = "is_public"
        case noteType     = "note_type"
        case iconEmoji    = "icon_emoji"
    }

    init(from note: Note, userId: UUID) {
        self.id           = note.id
        self.userId       = userId
        self.content      = note.content
        self.categoryId   = note.folderId ?? note.categoryId
        self.folderId     = note.folderId ?? note.categoryId
        self.createdAt    = note.createdAt
        self.updatedAt    = note.updatedAt
        self.locationLat  = note.locationLat
        self.locationLng  = note.locationLng
        self.locationName = note.locationName
        self.locationPoi  = note.locationPOI
        self.reminderAt   = note.reminderAt
        self.isDeleted    = note.isDeleted
        self.isFavorited  = note.isFavorited
        self.isPublic     = false
        self.noteType     = note.noteTypeRaw
        self.iconEmoji    = note.iconEmoji
    }
}

private struct NotePayloadLegacy: Encodable {
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
    let isFavorited: Bool
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
        case isFavorited  = "is_favorited"
        case isPublic     = "is_public"
    }

    init(from note: Note, userId: UUID) {
        self.id           = note.id
        self.userId       = userId
        self.content      = note.content
        self.categoryId   = note.folderId ?? note.categoryId
        self.createdAt    = note.createdAt
        self.updatedAt    = note.updatedAt
        self.locationLat  = note.locationLat
        self.locationLng  = note.locationLng
        self.locationName = note.locationName
        self.locationPoi  = note.locationPOI
        self.reminderAt   = note.reminderAt
        self.isDeleted    = note.isDeleted
        self.isFavorited  = note.isFavorited
        self.isPublic     = false
    }
}

private struct NoteRecord: Decodable {
    let id: UUID
    let content: String
    let categoryId: UUID?
    let folderId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let locationLat: Double?
    let locationLng: Double?
    let locationName: String?
    let locationPoi: String?
    let reminderAt: Date?
    let isDeleted: Bool
    let isFavorited: Bool?
    let noteType: String?
    let iconEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case categoryId   = "category_id"
        case folderId     = "folder_id"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case locationLat  = "location_lat"
        case locationLng  = "location_lng"
        case locationName = "location_name"
        case locationPoi  = "location_poi"
        case reminderAt   = "reminder_at"
        case isDeleted    = "is_deleted"
        case isFavorited  = "is_favorited"
        case noteType     = "note_type"
        case iconEmoji    = "icon_emoji"
    }
}

private struct FolderPayload: Encodable {
    let id: UUID
    let userId: UUID
    let name: String
    let parentId: UUID?
    let position: Int
    let colorHex: String?
    let iconEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case name
        case parentId  = "parent_id"
        case position
        case colorHex  = "color_hex"
        case iconEmoji = "icon_emoji"
    }

    init(from folder: Folder, userId: UUID) {
        self.id        = folder.id
        self.userId    = userId
        self.name      = folder.name
        self.parentId  = folder.parentId
        self.position  = folder.position
        self.colorHex  = folder.colorHex
        self.iconEmoji = folder.iconEmoji
    }
}

private struct FolderRecord: Decodable {
    let id: UUID
    let name: String
    let parentId: UUID?
    let position: Int
    let colorHex: String?
    let iconEmoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentId  = "parent_id"
        case position
        case colorHex  = "color_hex"
        case iconEmoji = "icon_emoji"
    }
}

private struct SmartFolderPayload: Encodable {
    let id: UUID
    let userId: UUID
    let name: String
    let filterJSON: String
    let position: Int
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case name
        case filterJSON = "filter_json"
        case position
        case isDeleted  = "is_deleted"
    }

    init(from folder: SmartFolder, userId: UUID) {
        self.id         = folder.id
        self.userId     = userId
        self.name       = folder.name
        self.filterJSON = folder.filterJSON
        self.position   = folder.position
        self.isDeleted  = false
    }
}

private struct SmartFolderRecord: Decodable {
    let id: UUID
    let name: String
    let filterJSON: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case filterJSON = "filter_json"
        case position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        if let json = try? c.decode(String.self, forKey: .filterJSON) {
            filterJSON = json
        } else if let obj = try? c.decode([String: String].self, forKey: .filterJSON),
                  let data = try? JSONEncoder().encode(obj),
                  let str = String(data: data, encoding: .utf8) {
            filterJSON = str
        } else {
            filterJSON = "{}"
        }
    }
}
