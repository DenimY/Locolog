import SwiftUI
import AuthenticationServices
#if os(macOS)
import Sparkle
#endif

// MARK: - SettingsView (플랫폼 분기)

struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        MacSettingsView()
        #else
        iOSSettingsView()
        #endif
    }
}

// ─────────────────────────────────────────
// MARK: - macOS 설정 (탭 기반)
// ─────────────────────────────────────────

#if os(macOS)
struct MacSettingsView: View {
    var body: some View {
        TabView {
            AccountTabView()
                .tabItem { Label("계정", systemImage: "person.circle") }
                .tag(0)

            AITabView()
                .tabItem { Label("AI", systemImage: "sparkles") }
                .tag(1)

            NotificationTabView()
                .tabItem { Label("알림", systemImage: "bell") }
                .tag(2)

            AboutTabView()
                .tabItem { Label("정보", systemImage: "info.circle") }
                .tag(3)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

// MARK: - 계정 탭

private struct AccountTabView: View {
    @ObservedObject private var auth = AuthManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            switch auth.authState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

            case .signedOut:
                signedOutContent

            case .signedIn(_, let email):
                signedInContent(email: email)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var signedOutContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("계정 연결")
                    .font(.title2.bold())
                Text("iPhone과 Mac 간에 메모를 동기화합니다.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await signInWithApple() }
                } label: {
                    HStack {
                        Image(systemName: "applelogo")
                        Text(isLoading ? "로그인 중..." : "Apple로 로그인")
                    }
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading)

                Button {
                    // Google Sign-In 추후 구현
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Google로 로그인")
                    }
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(true)
                .foregroundStyle(.secondary)
            }

            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.callout)
            }
        }
    }

    private func signedInContent(email: String?) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 6) {
                Text("동기화 활성화됨")
                    .font(.title2.bold())
                if let email {
                    Text(email)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("iPhone ↔ Mac 동기화 중")
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                Task { await signOut() }
            } label: {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func signInWithApple() async {
        isLoading = true; errorMessage = nil
        do {
            try await auth.signInWithApple()
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func signOut() async {
        do { try await auth.signOut() }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - AI 탭

private struct AITabView: View {
    @AppStorage("claudeAPIKey") private var claudeKey = ""
    @AppStorage("openAIAPIKey") private var openAIKey = ""
    @AppStorage("geminiAPIKey") private var geminiKey = ""

    private var activeProvider: AIProvider? {
        AIProvider.allCases.first {
            !(UserDefaults.standard.string(forKey: $0.keyStorageKey) ?? "")
                .trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 상태 배너
            HStack(spacing: 10) {
                if let p = activeProvider {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(p.rawValue) 활성화됨").fontWeight(.medium)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("API 키를 입력하면 AI 기능이 활성화됩니다").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))

            // API 키 입력
            VStack(alignment: .leading, spacing: 4) {
                Text("API 키").font(.headline)
                Text("키는 이 기기에만 저장되며 서버로 전송되지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                apiKeyRow(provider: .claude, binding: $claudeKey, color: .purple)
                apiKeyRow(provider: .openAI, binding: $openAIKey, color: .green)
                apiKeyRow(provider: .gemini, binding: $geminiKey, color: .blue)
            }

            Divider()

            // 명령어 안내
            VStack(alignment: .leading, spacing: 6) {
                Text("사용 가능한 명령어").font(.headline)
                ForEach(AICommand.allCases) { cmd in
                    Label(cmd.rawValue, systemImage: cmd.icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func apiKeyRow(provider: AIProvider, binding: Binding<String>, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: provider.iconName)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(provider.rawValue)
                .frame(width: 70, alignment: .leading)
            SecureField("API Key", text: binding)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - 알림 탭

private struct NotificationTabView: View {
    @ObservedObject private var nm = NotificationManager.shared
    @AppStorage("reminderDefaultHour") private var defaultHour = 9
    @AppStorage("googleCalendarEnabled") private var calendarEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 알림 권한
            VStack(alignment: .leading, spacing: 10) {
                Text("알림").font(.headline)
                HStack {
                    if nm.isAuthorized {
                        Label("알림 권한 허용됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("알림 권한 없음", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        Button("권한 요청") {
                            Task { await nm.requestPermission() }
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))

                HStack {
                    Text("기본 알림 시각")
                    Spacer()
                    Picker("", selection: $defaultHour) {
                        ForEach(0..<24, id: \.self) { Text("\($0)시").tag($0) }
                    }
                    .frame(width: 90)
                    .labelsHidden()
                }
            }

            Divider()

            // Google 캘린더
            VStack(alignment: .leading, spacing: 10) {
                Text("Google 캘린더").font(.headline)
                Toggle("Google 캘린더 연동", isOn: $calendarEnabled)
                Text("연동 시 calendar.events 권한이 요청됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
                if calendarEnabled {
                    Label("연동 준비 중 (추후 업데이트)", systemImage: "clock")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await nm.checkStatus() }
    }
}

// MARK: - 정보 탭

private struct AboutTabView: View {
    private let updater = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    ).updater

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 앱 아이콘 + 이름
            VStack(spacing: 12) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                Text("Locolog")
                    .font(.title.bold())
                Text("버전 \(version)")
                    .foregroundStyle(.secondary)
            }

            // 액션 버튼
            VStack(spacing: 10) {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("업데이트 확인", systemImage: "arrow.clockwise.circle")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                NavigationLink {
                    Text("오픈소스 라이센스")
                        .padding()
                } label: {
                    Label("오픈소스 라이센스", systemImage: "doc.text")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
#endif

// ─────────────────────────────────────────
// MARK: - iOS 설정 (NavigationStack 유지)
// ─────────────────────────────────────────

#if os(iOS)
private struct iOSSettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("계정 & 동기화") {
                    NavigationLink { AccountView() } label: {
                        Label("계정 연결", systemImage: "person.circle")
                    }
                }
                Section("AI 연동") {
                    NavigationLink { AISettingsView() } label: {
                        Label("AI 설정", systemImage: "sparkles")
                    }
                }
                Section("알림 & 캘린더") {
                    NavigationLink { NotificationSettingsView() } label: {
                        Label("알림", systemImage: "bell")
                    }
                    NavigationLink { GoogleCalendarSettingsView() } label: {
                        Label("Google 캘린더", systemImage: "calendar.badge.plus")
                    }
                }
                Section("정보") {
                    LabeledContent("버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    NavigationLink { Text("오픈소스 라이센스").padding() } label: {
                        Label("오픈소스 라이센스", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - iOS 하위 뷰 (기존 코드 유지)

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            switch authManager.authState {
            case .loading:
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            case .signedOut:
                signedOutSection
            case .signedIn(_, let email):
                signedInSection(email: email)
            }
        }
        .navigationTitle("계정")
        .navigationBarTitleDisplayMode(.large)
    }

    private var signedOutSection: some View {
        Group {
            Section {
                Button {
                    Task { await signInWithApple() }
                } label: {
                    if isLoading {
                        HStack { ProgressView().scaleEffect(0.8); Text("로그인 중...") }
                    } else {
                        Label("Apple로 로그인하여 동기화", systemImage: "applelogo")
                    }
                }
                .disabled(isLoading)

                Button {
                } label: {
                    Label("Google로 로그인하여 동기화", systemImage: "g.circle")
                }
                .foregroundStyle(.secondary)
                .disabled(true)
            } footer: {
                Text("로그인하면 iPhone과 Mac 간에 메모가 자동으로 동기화됩니다.")
            }
            if let error = errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.callout) }
            }
        }
    }

    private func signedInSection(email: String?) -> some View {
        Group {
            Section {
                if let email { LabeledContent("계정", value: email) }
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
        isLoading = true; errorMessage = nil
        do { try await authManager.signInWithApple() }
        catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func signOut() async {
        do { try await authManager.signOut() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct NotificationSettingsView: View {
    @ObservedObject private var notificationManager = NotificationManager.shared
    @AppStorage("reminderDefaultHour") private var defaultHour = 9

    var body: some View {
        Form {
            Section {
                if notificationManager.isAuthorized {
                    Label("알림 권한 허용됨", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button {
                        Task { await notificationManager.requestPermission() }
                    } label: {
                        Label("알림 권한 요청", systemImage: "bell.badge")
                    }
                }
            } header: { Text("권한") } footer: {
                Text("메모에 알림을 설정하려면 권한이 필요합니다.")
            }
            Section("기본 알림 시각") {
                Picker("시각", selection: $defaultHour) {
                    ForEach(0..<24, id: \.self) { Text("\($0)시").tag($0) }
                }
                .pickerStyle(.wheel)
            }
        }
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.large)
        .task { await notificationManager.checkStatus() }
    }
}

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
                    Label("연동 준비 중 (추후 업데이트)", systemImage: "clock").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Google 캘린더")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AISettingsView: View {
    @AppStorage("claudeAPIKey") private var claudeKey = ""
    @AppStorage("openAIAPIKey") private var openAIKey = ""
    @AppStorage("geminiAPIKey") private var geminiKey = ""

    private var activeProvider: AIProvider? {
        AIProvider.allCases.first {
            !(UserDefaults.standard.string(forKey: $0.keyStorageKey) ?? "")
                .trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        Form {
            Section {
                if let provider = activeProvider {
                    HStack(spacing: 8) {
                        Image(systemName: provider.iconName).foregroundStyle(Color.accentColor)
                        Text("\(provider.rawValue) 활성화됨").fontWeight(.medium)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("API 키를 입력하면 AI 기능이 활성화됩니다").foregroundStyle(.secondary)
                    }
                }
            } header: { Text("상태") }

            Section {
                HStack {
                    Image(systemName: AIProvider.claude.iconName).frame(width: 20).foregroundStyle(.purple)
                    SecureField("Claude API Key", text: $claudeKey)
                }
                HStack {
                    Image(systemName: AIProvider.openAI.iconName).frame(width: 20).foregroundStyle(.green)
                    SecureField("OpenAI API Key", text: $openAIKey)
                }
                HStack {
                    Image(systemName: AIProvider.gemini.iconName).frame(width: 20).foregroundStyle(.blue)
                    SecureField("Gemini API Key", text: $geminiKey)
                }
            } header: { Text("API 키") } footer: {
                Text("API 키는 이 기기에만 저장됩니다.\nClaude → OpenAI → Gemini 순서로 우선 적용됩니다.")
            }

            Section {
                ForEach(AICommand.allCases) { command in
                    Label(command.rawValue, systemImage: command.icon).font(.subheadline)
                }
            } header: { Text("사용 가능한 AI 명령어") } footer: {
                Text("메모 편집 화면의 ✦ 버튼을 눌러 AI 도구를 사용하세요.")
            }
        }
        .navigationTitle("AI 설정")
        .navigationBarTitleDisplayMode(.large)
    }
}
#endif
