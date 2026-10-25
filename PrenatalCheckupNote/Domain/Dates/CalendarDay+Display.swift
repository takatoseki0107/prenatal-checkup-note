import Foundation

extension CalendarDay {
    /// 曜日の短い名前。`Calendar` の `weekday`（1 が日曜日）の順。
    private nonisolated static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    /// 画面に出す日付。例：「10月25日（日）」。
    ///
    /// 曜日は `Calendar.japan` で決めるので、iPhone の言語や地域の設定によらず同じになる（R-90）。
    nonisolated var displayText: String {
        let weekday = Calendar.japan.component(.weekday, from: date(hour: 12))
        let symbol = Self.weekdaySymbols[(weekday - 1) % 7]
        return "\(month)月\(day)日（\(symbol)）"
    }
}
