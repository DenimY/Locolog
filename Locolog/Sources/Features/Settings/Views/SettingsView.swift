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
                        NotificationSettingsView()
                    } label: {
                        Label("알림", systemImage: "bell")
                    }

                    NavigationLink {
                        GoogleCalendarSettingsView()
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

// MARK: - 알림 설정

struct NotificationSettingsView: View {
    @ObservedObject private var notificationManager = NotificationManager.shared
    @AppStorage("reminderDefaultHour") private var defaultHour = 9

    var body: some View {
        Form {
            Section {
                if notificationManager.isAuthorized {
                    Label("알림 권한 허용됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await notificationManager.requestPermission() }
                    } label: {
                        Label("알림 권한 요청", systemImage: "bell.badge")
                    }
                }
            } header: {
                Text("권한")
            } footer: {
                Text("메모에 알림을 설정하려면 권한이 필요합니다.")
            }

            Section("기본 알림 시각") {
                Picker("시각", selection: $defaultHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour)시").tag(hour)
                    }
                }
                #if os(iOS)
                .pickerStyle(.wheel)
                #endif
            }
        }
        .navigationTitle("알림")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { await notificationManager.checkStatus() }
    }
}

// MARK: - Google 캘린더 설정 (인프라 준비, 연동은 Phase 3)

struct GoogleCalendarSettingsView: View {
    @AppStorage("googleCalendarEnabled") private var isEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $isEnabled) {
                    Label("Google 캘린더 연동", systemImage: "calendar.badge.plus")
                }
            } footer: {
                Text("메모의 날짜와 위치를 Google 캘린더 일정과 연결합니다.\n연동 시 calendar.events 권한이 요청됩니다.")
            }

            if isEnabled {
                Section("연결 상태") {
                    Label("연동 준비 중 (추후 업데이트)", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Google 캘린더")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

struct AISettingsView: View {
    @AppStorage("claudeAPIKey")   private var claudeKey   = ""
    @AppStorage("openAIAPIKey")   private var openAIKey   = ""
    @AppStorage("geminiAPIKey")   private var geminiKey   = ""

    private var activeProvider: AIProvider? {
        for provider in AIProvider.allCases {
            let key = UserDefaults.standard.string(forKey: provider.keyStorageKey) ?? ""
            if !key.trimmingCharacters(in: .whitespaces).isEmpty { return provider }
        }
        return nil
    }

    var body: some View {
        Form {
            // 현재 활성 프로바이더 표시
            Section {
                if let provider = activeProvider {
                    HStack(spacing: 8) {
                        Image(systemName: provider.iconName)
                            .foregroundStyle(Color.accentColor)
                        Text("\(provider.rawValue) 활성화됨")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("API 키를 입력하면 AI 기능이 활성화됩니다")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("상태")
            }

            // API 키 입력
            Section {
                HStack {
                    Image(systemName: AIProvider.claude.iconName)
                        .frame(width: 20)
                        .foregroundStyle(.purple)
                    SecureField("Claude API Key", text: $claudeKey)
                }
                HStack {
                    Image(systemName: AIProvider.openAI.iconName)
                        .frame(width: 20)
                        .foregroundStyle(.green)
                    SecureField("OpenAI API Key", text: $openAIKey)
                }
                HStack {
                    Image(systemName: AIProvider.gemini.iconName)
                        .frame(width: 20)
                        .foregroundStyle(.blue)
                    SecureField("Gemini API Key", text: $geminiKey)
                }
            } header: {
                Text("API 키")
            } footer: {
                Text("API 키는 이 기기에만 저장되며 서버로 전송되지 않습니다.\nClaude → OpenAI → Gemini 순서로 우선 적용됩니다.\nAI 기능은 선택 사항입니다.")
            }

            // 사용 가능한 명령어 안내
            Section {
                ForEach(AICommand.allCases) { command in
                    Label(command.rawValue, systemImage: command.icon)
                        .font(.subheadline)
                }
            } header: {
                Text("사용 가능한 AI 명령어")
            } footer: {
                Text("메모 편집 화면의 ✦ 버튼을 눌러 AI 도구를 사용하세요.")
            }
        }
        .navigationTitle("AI 설정")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}
