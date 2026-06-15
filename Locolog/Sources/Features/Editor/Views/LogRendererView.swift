import SwiftUI

// MARK: - Log Level

enum LogLevel {
    case error, warn, info, debug, verbose, none

    var color: Color {
        switch self {
        case .error:   return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .warn:    return Color(red: 1.0, green: 0.75, blue: 0.2)
        case .info:    return Color(red: 0.3, green: 0.75, blue: 1.0)
        case .debug:   return Color(red: 0.4, green: 0.85, blue: 0.5)
        case .verbose: return Color(white: 0.6)
        case .none:    return Color(white: 0.82)
        }
    }

    var badge: String {
        switch self {
        case .error:   return "ERR"
        case .warn:    return "WRN"
        case .info:    return "INF"
        case .debug:   return "DBG"
        case .verbose: return "VRB"
        case .none:    return ""
        }
    }

    static func detect(in line: String) -> LogLevel {
        let u = line.uppercased()
        if u.contains("ERROR") || u.contains("FATAL") || u.contains("EXCEPTION") || u.contains("FAIL") { return .error }
        if u.contains("WARN") { return .warn }
        if u.contains("INFO") || u.contains("SUCCESS") { return .info }
        if u.contains("DEBUG") { return .debug }
        if u.contains("VERBOSE") || u.contains("TRACE") { return .verbose }
        return .none
    }
}

// MARK: - Log Line

struct LogLine: Identifiable {
    let id = UUID()
    let level: LogLevel
    let cleaned: String

    init(_ raw: String) {
        self.level = LogLevel.detect(in: raw)
        // ANSI 이스케이프 코드 제거
        self.cleaned = raw.replacingOccurrences(
            of: #"\x1B\[[0-9;]*[mGKHFJABCDsurh]"#,
            with: "", options: .regularExpression
        )
    }
}

// MARK: - LogRendererView

struct LogRendererView: View {
    let content: String

    private var lines: [LogLine] {
        content.components(separatedBy: "\n").map { LogLine($0) }
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(lines) { line in
                    LogLineRow(line: line)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
}

// MARK: - Log Line Row

private struct LogLineRow: View {
    let line: LogLine

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if line.level != .none {
                Text(line.level.badge)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(line.level.color))
                    .fixedSize()
            } else {
                Spacer().frame(width: 31)
            }

            Text(line.cleaned.isEmpty ? " " : line.cleaned)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(line.level.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}
