import SwiftUI
import SwiftData

@main
struct LocologApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Note.self,
            Category.self,
            Tag.self,
            SmartFolder.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // 1차 시도: 정상 오픈
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // 2차 시도: 스키마 변경으로 기존 스토어 열기 실패 시 삭제 후 재생성
        // (개발 단계에서만 허용 — 로컬 미동기화 데이터 유실 가능)
        print("⚠️ SwiftData: 스키마 마이그레이션 실패, 스토어를 초기화합니다.")
        let storeBase = URL.applicationSupportDirectory.appending(path: "default.store")
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeBase.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainer 생성 실패: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
