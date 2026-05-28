import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isSyncLoading = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                Text("Locolog")
                    .font(.largeTitle.bold())
                Text("무지성으로 던져도\n날짜와 장소로 자동 정리")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "location.fill",  text: "메모하면 장소가 자동으로 기록됩니다")
                FeatureRow(icon: "calendar",        text: "날짜별로 메모를 캘린더에서 확인합니다")
                FeatureRow(icon: "magnifyingglass", text: "장소·날짜·태그로 빠르게 검색합니다")
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                // 로컬로 시작 — 기본, 크게
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("로컬로 시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Apple 계정 연결 — 보조, 작게
                Button {
                    Task { await signInForSync() }
                } label: {
                    if isSyncLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text("Apple로 시작하기 (동기화)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isSyncLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func signInForSync() async {
        isSyncLoading = true
        do {
            try await AuthManager.shared.signInWithApple()
        } catch {
            // 취소하거나 실패해도 로컬로 계속 진행 가능
        }
        isSyncLoading = false
        hasCompletedOnboarding = true
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .font(.callout)
        }
    }
}
