import SwiftUI

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

// MARK: - Placeholder Views (Phase 2~3에서 구현)
struct AccountView: View {
    var body: some View {
        Form {
            Section {
                // Phase 2: Apple / Google 로그인 (동등 위계)
                Button {
                } label: {
                    Label("Apple로 로그인하여 동기화", systemImage: "applelogo")
                }
                Button {
                } label: {
                    Label("Google로 로그인하여 동기화", systemImage: "g.circle")
                }
            } footer: {
                Text("로그인하면 iPhone과 Mac 간에 메모가 동기화됩니다.")
            }
        }
        .navigationTitle("계정")
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
