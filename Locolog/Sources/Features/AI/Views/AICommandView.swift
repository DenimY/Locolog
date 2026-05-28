import SwiftUI

struct AICommandView: View {
    let note: Note
    let onAppend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiManager = AIManager.shared

    @State private var result: String = ""
    @State private var errorMessage: String?
    @State private var selectedCommand: AICommand?
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 커맨드 버튼들
                commandGrid
                    .padding()

                Divider()

                // 결과 영역
                resultArea
            }
            .navigationTitle("AI 도구")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if !result.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onAppend(result)
                            dismiss()
                        } label: {
                            Label("추가", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 520)
        #endif
    }

    // MARK: - Command Grid

    private var commandGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerBadge

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(AICommand.allCases) { command in
                    commandButton(command)
                }
            }
        }
    }

    @ViewBuilder
    private var providerBadge: some View {
        if let provider = AIManager.shared.activeProvider {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.caption)
                Text(provider.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("사용 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("API 키를 설정 > AI 설정에서 입력하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1), in: Capsule())
        }
    }

    private func commandButton(_ command: AICommand) -> some View {
        Button {
            Task { await runCommand(command) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: command.icon)
                    .font(.title3)
                    .foregroundStyle(selectedCommand == command ? Color.white : Color.accentColor)
                Text(command.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(selectedCommand == command ? Color.white : Color.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedCommand == command
                          ? Color.accentColor
                          : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(aiManager.isLoading || AIManager.shared.activeProvider == nil)
    }

    // MARK: - Result Area

    @ViewBuilder
    private var resultArea: some View {
        if aiManager.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("AI가 분석 중입니다...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("다시 시도") {
                    if let cmd = selectedCommand {
                        Task { await runCommand(cmd) }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if result.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("위의 명령을 눌러 AI 분석을 시작하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            VStack(spacing: 0) {
                // 결과 텍스트
                ScrollView {
                    Text(result)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }

                Divider()

                // 하단 액션 버튼
                HStack(spacing: 12) {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = result
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                        #endif
                        withAnimation { showCopied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        Label(showCopied ? "복사됨" : "복사", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onAppend(result)
                        dismiss()
                    } label: {
                        Label("메모에 추가", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    // MARK: - Run

    private func runCommand(_ command: AICommand) async {
        guard !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "메모 내용이 없습니다. 먼저 내용을 입력해 주세요."
            return
        }
        selectedCommand = command
        errorMessage = nil
        result = ""

        do {
            result = try await AIManager.shared.execute(command: command, noteContent: note.content)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
