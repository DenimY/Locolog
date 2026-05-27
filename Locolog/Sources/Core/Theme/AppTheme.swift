import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let accent = Color.accentColor   // 사용 시 Color.accentColor 직접 참조 권장

    // MARK: - Typography
    static let noteBodyFont = Font.system(.body, design: .default)
    static let noteCodeFont = Font.system(.body, design: .monospaced)
    static let listTitleFont = Font.system(.callout, weight: .medium)
    static let listMetaFont  = Font.system(.caption, weight: .regular)

    // MARK: - Spacing
    static let editorHPadding: CGFloat = 16
    static let listRowVPadding: CGFloat = 6
}

// MARK: - Color hex initializer
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }
}
