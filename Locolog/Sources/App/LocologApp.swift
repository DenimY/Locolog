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

        // iOS: App Group 컨테이너에 저장 (위젯과 공유)
        // macOS: 기본 Application Support 경로 사용
        let storeURL: URL = {
            #if os(iOS)
            if let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.locolog.app"
            ) {
                let dir = groupURL
                    .appending(path: "Library", directoryHint: .isDirectory)
                    .appending(path: "Application Support", directoryHint: .isDirectory)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir.appending(path: "default.store")
            }
            #endif
            return URL.applicationSupportDirectory.appending(path: "default.store")
        }()

        let config = ModelConfiguration(schema: schema, url: storeURL)

        // 1차 시도: 정상 오픈
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ SwiftData: ModelContainer 생성 실패 — \(error)")
        }

        // 2차 시도: 스토어 손상·마이그레이션 실패 시 타임스탬프 백업 후 재생성
        let timestamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let backup = URL(fileURLWithPath: storeURL.path + suffix + ".backup-\(timestamp)")
            try? FileManager.default.moveItem(at: source, to: backup)
        }
        print("⚠️ SwiftData: 스토어를 backup-\(timestamp)로 백업하고 새 스토어를 생성합니다.")

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
