import SwiftUI
import MarkdownUI
import Highlightr

/// swift-markdown-ui 와 Highlightr 를 연결하는 코드 문법 강조기
struct HighlightrCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    let colorScheme: ColorScheme

    private var themeName: String {
        colorScheme == .dark ? "atom-one-dark" : "xcode"
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard let hl = Highlightr() else {
            return fallback(code)
        }
        hl.setTheme(to: themeName)

        let lang = language?.lowercased() ?? "plaintext"
        guard let nsAttr = hl.highlight(code, as: lang, fastRender: true) else {
            return fallback(code)
        }

        #if os(iOS)
        if let attr = try? AttributedString(nsAttr, including: \.uiKit) {
            return Text(attr)
        }
        #elseif os(macOS)
        if let attr = try? AttributedString(nsAttr, including: \.appKit) {
            return Text(attr)
        }
        #endif
        return fallback(code)
    }

    private func fallback(_ code: String) -> Text {
        Text(code).font(.system(.body, design: .monospaced))
    }
}

extension CodeSyntaxHighlighter where Self == HighlightrCodeSyntaxHighlighter {
    static func highlightr(colorScheme: ColorScheme) -> Self {
        .init(colorScheme: colorScheme)
    }
}
