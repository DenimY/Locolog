import SwiftUI
import SwiftData
#if os(macOS)
import Sparkle
#endif

@main
struct LocologApp: App {
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue

    private var appLocale: Locale? {
        let lang = AppLanguage(rawValue: appLanguageRaw) ?? .system
        return lang == .system ? nil : lang.locale
    }

    #if os(macOS)
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #endif

    init() {
        Self.cleanUpLegacyPreviewModeKeys()
        Self.migrateCategoriesToFolders(container: container)
    }

    /// 과거 버전에서 노트별 미리보기 모드를 UserDefaults에 "previewMode_<uuid>" 키로 저장했던
    /// 잔여 데이터를 제거한다. 노트가 많아질수록 plist가 비대해져 전체 UserDefaults 읽기/쓰기가
    /// 느려지는 문제가 있어, isPreviewMode를 Note 모델로 옮기면서 기존 키를 정리한다.
    private static func cleanUpLegacyPreviewModeKeys() {
        let defaults = UserDefaults.standard
        let cleanedFlagKey = "didCleanUpLegacyPreviewModeKeys"
        guard !defaults.bool(forKey: cleanedFlagKey) else { return }

        let legacyKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("previewMode_") }
        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: cleanedFlagKey)
    }

    /// 카테고리(평면, 메모당 1개)를 트리형 폴더로 흡수 통합한다.
    /// 기존 Category와 동일한 id로 최상위 Folder를 생성해 categoryId 참조가
    /// 그대로 folderId로 재사용될 수 있게 하고, 메모/스마트폴더의 참조도 옮긴다.
    private static func migrateCategoriesToFolders(container: ModelContainer) {
        let defaults = UserDefaults.standard
        let flagKey = "didMigrateCategoriesToFolders"
        guard !defaults.bool(forKey: flagKey) else { return }

        let context = ModelContext(container)
        guard let categories = try? context.fetch(FetchDescriptor<Category>()), !categories.isEmpty else {
            defaults.set(true, forKey: flagKey)
            return
        }

        for category in categories {
            let folder = Folder(name: category.name, parentId: nil, position: category.position, colorHex: category.colorHex)
            folder.id = category.id
            context.insert(folder)
        }

        if let notes = try? context.fetch(FetchDescriptor<Note>()) {
            for note in notes where note.folderId == nil && note.categoryId != nil {
                note.folderId = note.categoryId
            }
        }

        if let smartFolders = try? context.fetch(FetchDescriptor<SmartFolder>()) {
            for sf in smartFolders {
                var filter = sf.filter
                guard filter.folderId == nil, let legacyCategoryId = filter.categoryId else { continue }
                filter.folderId = legacyCategoryId
                if let json = (try? JSONEncoder().encode(filter)).flatMap({ String(data: $0, encoding: .utf8) }) {
                    sf.filterJSON = json
                }
            }
        }

        try? context.save()
        defaults.set(true, forKey: flagKey)
    }

    let container: ModelContainer = {
        let schema = Schema([
            Note.self,
            Category.self,
            Tag.self,
            SmartFolder.self,
            Folder.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // 1차 시도: 정상 오픈
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 실패 원인을 반드시 로그로 남긴다 — 원인을 모르면 같은 문제가 재발해도 알 수 없다.
            print("⚠️ SwiftData: ModelContainer 생성 실패 — \(error)")
        }

        // 2차 시도: 손상되었거나 마이그레이션 불가능한 스토어를 "삭제"하지 않고
        // 타임스탬프를 붙여 백업 위치로 옮긴 뒤 새 스토어를 만든다.
        // (예전엔 바로 삭제했는데, 스키마를 자주 바꾸는 개발 중 lightweight 마이그레이션이
        //  실패할 때마다 사용자 데이터가 통째로 사라지는 사고로 이어졌음 — 절대 삭제 금지)
        let timestamp = Int(Date().timeIntervalSince1970)

        func backupStoreFiles(at base: URL) {
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: base.path + suffix)
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                let backup = URL(fileURLWithPath: base.path + suffix + ".backup-\(timestamp)")
                try? FileManager.default.moveItem(at: source, to: backup)
            }
        }

        // 기본 앱 경로
        backupStoreFiles(at: URL.applicationSupportDirectory.appending(path: "default.store"))

        // App Group 경로 (위젯과 공유하는 컨테이너) — 실제 스토어가 여기 있을 수도 있다.
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.locolog.app") {
            let groupStore = groupURL
                .appending(path: "Library", directoryHint: .isDirectory)
                .appending(path: "Application Support", directoryHint: .isDirectory)
                .appending(path: "default.store")
            backupStoreFiles(at: groupStore)
        }

        print("⚠️ SwiftData: 기존 스토어를 default.store.backup-\(timestamp)로 백업하고 새 스토어를 생성합니다.")

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer 생성 실패 (백업 후 재시도도 실패): \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, appLocale ?? Locale.autoupdatingCurrent)
                #if os(macOS)
                .onAppear {
                    updaterController.updater.checkForUpdatesInBackground()
                }
                #endif
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(\.sparkleUpdater, updaterController.updater)
                .environment(\.locale, appLocale ?? Locale.autoupdatingCurrent)
        }
        #endif
    }
}
