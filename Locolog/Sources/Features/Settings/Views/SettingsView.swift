import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                // 계정 & 동기화 (Phase 2)
                Section("계정 & 동기화") {
                    NavigationLink {
                        AccountView()
                    } label: {
                        Label("계정 연결", systemImage: "person.circle")
                    }
                }

                // AI 연동 (Phase 3)
                Section("AI 연동") {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        Label("AI 설정", systemImage: "sparkles")
                    }
                }

                // 알림 & 캘린더
                Section("알림 & 캘린더") {
                    NavigationLink {
                        Text("알림 설정 (Phase 2)")
                    } label: {
                        Label("알림", systemImage: "bell")
                    }

                    NavigationLink {
                        Text("Google 캘린더 연동 (Phase 2)")
                    } label: {
                        Label("Google 캘린더", systemImage: "calendar.badge.plus")
                    }
                }

                // 정보
                Section("정보") {
                    LabeledContent("버전", value: "1.0.0")
                    NavigationLink {
                        Text("오픈소스 라이센스")
                    } label: {
                        Label("오픈소스 라이센스", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - 계정 관리

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            switch authManager.authState {
            case .loading:
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            case .signedOut:
                signedOutSection
            case .signedIn(_, let email):
                signedInSection(email: email)
            }
        }
        .navigationTitle("계정")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var signedOutSection: some View {
        Group {
            Section {
                Button {
                    Task { await signInWithApple() }
                } label: {
                    if isLoading {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("로그인 중...")
                        }
                    } else {
                        Label("Apple로 로그인하여 동기화", systemImage: "applelogo")
                    }
                }
                .disabled(isLoading)

                Button {
                    // Google Sign-In: STEP 8에서 구현
                } label: {
                    Label("Google로 로그인하여 동기화", systemImage: "g.circle")
                }
                .foregroundStyle(.secondary)
                .disabled(true)
            } footer: {
                Text("로그인하면 iPhone과 Mac 간에 메모가 자동으로 동기화됩니다.")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
    }

    private func signedInSection(email: String?) -> some View {
        Group {
            Section {
                if let email {
                    LabeledContent("계정", value: email)
                }
                LabeledContent("동기화 상태", value: "활성화")
            }
            Section {
                Button(role: .destructive) {
                    Task { await signOut() }
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.signInWithApple()
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func signOut() async {
        do {
            try await authManager.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AISettingsView: View {
    @AppStorage("claudeAPIKey")   private var claudeKey   = ""
    @AppStorage("openAIAPIKey")   private var openAIKey   = ""
    @AppStorage("geminiAPIKey")   private var geminiKey   = ""

    var body: some View {
        Form {
            Section {
                SecureField("Claude API Key", text: $claudeKey)
                SecureField("OpenAI API Key", text: $openAIKey)
                SecureField("Gemini API Key", text: $geminiKey)
            } header: {
                Text("AI 연동")
            } footer: {
                Text("API 키는 이 기기에만 저장되며 서버로 전송되지 않습니다. AI 기능은 선택 사항입니다.")
            }
        }
        .navigationTitle("AI 설정")
    }
}
