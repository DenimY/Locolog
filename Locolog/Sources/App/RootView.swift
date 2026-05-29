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
            AuthManager.shared.restoreSession()
            if authManager.isSignedIn {
                await SyncManager.shared.sync(context: context)
            }
            updateWidget()
        }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await SyncManager.shared.sync(context: context) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if authManager.isSignedIn {
                    Task { await SyncManager.shared.sync(context: context) }
                }
                updateWidget()
            }
        }
        .onChange(of: allNotes) { _, notes in
            // 메모가 변경되면 위젯 데이터 갱신
            WidgetDataManager.update(with: Array(notes.prefix(5)))
        }
    }

    private func updateWidget() {
        WidgetDataManager.update(with: Array(allNotes.prefix(5)))
    }
}
