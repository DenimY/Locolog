import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authManager = AuthManager.shared

    // 위젯 업데이트용 최근 메모 쿼리
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(isPresented: .constant(true))
            }
        }
        .task {
            await AuthManager.shared.restoreSession()
            SyncManager.shared.attach(context: context)
            if authManager.isSignedIn {
                await SyncManager.shared.start(context: context)
            }
            updateWidget()
        }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await SyncManager.shared.start(context: context) }
            } else {
                SyncManager.shared.stop()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if authManager.isSignedIn {
                    Task { await SyncManager.shared.sync(context: context) }
                }
                updateWidget()
            case .inactive, .background:
                try? context.save()
                if authManager.isSignedIn {
                    SyncManager.shared.scheduleSync(context: context)
                }
                updateWidget()
            default:
                break
            }
        }
        .onChange(of: allNotes) { _, notes in
            WidgetDataManager.update(with: Array(notes.prefix(5)))
        }
        .onOpenURL { url in
            DeepLinkRouter.shared.handle(url)
        }
    }

    private func updateWidget() {
        WidgetDataManager.update(with: Array(allNotes.prefix(5)))
    }
}
