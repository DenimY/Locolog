import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(isPresented: .constant(true))
            }
        }
        .task {
            // 앱 시작 시 세션 복원 → 로그인 상태면 전체 sync
            AuthManager.shared.restoreSession()
            if authManager.isSignedIn {
                await SyncManager.shared.sync(context: context)
            }
        }
        .onChange(of: authManager.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await SyncManager.shared.sync(context: context) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && authManager.isSignedIn {
                Task { await SyncManager.shared.sync(context: context) }
            }
        }
    }
}
