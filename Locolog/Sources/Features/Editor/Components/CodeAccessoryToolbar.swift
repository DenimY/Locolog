import SwiftUI

/// iPhone 키보드 위 개발자 코드 입력 툴바
struct CodeAccessoryToolbar: View {
    let onInsert: (String) -> Void

    @State private var showLanguagePicker = false

    private let snippets: [(label: String, value: String)] = [
        ("```", "```\n\n```"),
        ("{}", "{\n  \n}"),
        ("[]", "[]"),
        ("()", "()"),
        ("_", "_"),
        ("->", "->"),
        ("//", "// "),
    ]

    private let languages = ["swift", "python", "javascript", "typescript",
                              "bash", "json", "sql", "kotlin", "rust", "go"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(snippets, id: \.label) { item in
                    Button(item.label) { onInsert(item.value) }
                        .buttonStyle(CodeToolbarButtonStyle())
                }

                Divider().frame(height: 20)

                // 언어 선택 → 코드 블록 자동 생성
                Menu {
                    ForEach(languages, id: \.self) { lang in
                        Button(lang) {
                            onInsert("```\(lang)\n\n```")
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("언어")
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .buttonStyle(CodeToolbarButtonStyle())
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
    }
}

struct CodeToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(configuration.isPressed ? .secondary : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed
                          ? Color(.systemGray4)
                          : Color(.systemGray5))
            )
    }
}
