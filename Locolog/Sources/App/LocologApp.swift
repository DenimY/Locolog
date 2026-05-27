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
