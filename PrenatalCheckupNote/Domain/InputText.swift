import Foundation

/// 入力された文の扱い。要件定義 v0.4 R-12。
nonisolated enum InputText {
    /// 前後の空白と改行（全角の空白も含む）を除いた文。空白と改行だけなら `nil`（空として扱う）。
    static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
