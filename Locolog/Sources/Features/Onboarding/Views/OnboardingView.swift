import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isAppleLoading = false
    @State private var isGoogleLoading = false

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
                FeatureRow(icon: "square.and.pencil", text: "던지면 시각과 장소가 붙습니다")
                FeatureRow(icon: "mappin.and.ellipse", text: "회사·마트·집이 곧 목차가 됩니다")
                FeatureRow(icon: "hand.draw", text: "더 나누려면 아이콘을 끌어다 붙입니다")
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
                .accessibilityIdentifier("startLocallyButton")

                // Apple 계정 연결
                Button {
                    Task { await signInWithApple() }
                } label: {
                    if isAppleLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Apple로 시작하기 (동기화)", systemImage: "applelogo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isAppleLoading || isGoogleLoading)

                // Google 계정 연결
                Button {
                    Task { await signInWithGoogle() }
                } label: {
                    if isGoogleLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Google로 시작하기 (동기화)", systemImage: "g.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isAppleLoading || isGoogleLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func signInWithApple() async {
        isAppleLoading = true
        do {
            try await AuthManager.shared.signInWithApple()
        } catch {
            // 취소하거나 실패해도 로컬로 계속 진행 가능
        }
        isAppleLoading = false
        hasCompletedOnboarding = true
    }

    private func signInWithGoogle() async {
        isGoogleLoading = true
        do {
            try await AuthManager.shared.signInWithGoogle()
        } catch {
            // 취소하거나 실패해도 로컬로 계속 진행 가능
        }
        isGoogleLoading = false
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
            Text(LocalizedStringKey(text))
                .font(.callout)
        }
    }
}
