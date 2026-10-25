import Foundation

extension NextCheckupSuggestion {
    /// 目安の日付の理由（R-30）。次の健診のシートで、日付の下に出す。
    nonisolated var reasonText: String {
        switch reason {
        case .standardInterval(let age):
            "最初の日付は、前回の健診（妊娠 \(age.weeks) 週）の標準の間隔（\(intervalDays / 7) 週間）から入れています。"
        case .sameAsLastInterval:
            "最初の日付は、前回と同じ間隔（\(intervalDays) 日）にしています。"
        case .defaultInterval:
            "最初の日付は、2 週間後にしています（前回の間隔がわからないため）。"
        }
    }

    /// 「1 / 2 / 4 週間後」のボタンの上に出す、数え始める日の説明（R-32）。
    ///
    /// - Parameter lastVisit: 前回の健診（いちばん新しい健診後メモ）の受診日。なければ今日から数える。
    nonisolated static func baseLabel(lastVisit: CalendarDay?, today: CalendarDay) -> String {
        if let lastVisit {
            return "前回の健診（\(lastVisit.displayText)）から"
        }
        return "今日（\(today.displayText)）から"
    }
}
