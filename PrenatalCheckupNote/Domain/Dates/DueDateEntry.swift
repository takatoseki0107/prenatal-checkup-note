import Foundation

/// 出産予定日の入力（はじめに・設定）。予定日を直接入れるか、いまの週数から計算する（要件定義 v0.4 の 4 章「はじめに」）。
///
/// 画面から切り離して、テストで確かめられるようにする。
nonisolated struct DueDateEntry: Equatable, Sendable {
    nonisolated enum Mode: Equatable, Sendable {
        /// 出産予定日を直接入れる。
        case date
        /// いまの週数から計算する。
        case weeks
    }

    var mode: Mode = .date
    /// 直接入れた出産予定日。まだ選んでいなければ `nil`。
    var date: CalendarDay?
    /// いまの週数。まだ選んでいなければ `nil`。
    var weeks: Int?
    /// いまの週数の日（0〜6）。
    var days: Int = 0

    /// 入力から決まる出産予定日。まだ決まらなければ `nil`。
    func dueDate(today: CalendarDay) -> CalendarDay? {
        switch mode {
        case .date:
            date
        case .weeks:
            weeks.flatMap { GestationalAge.dueDate(weeks: $0, days: days, today: today) }
        }
    }

    /// 日付を選ぶ欄の最初の日付。今日から 20 週後（妊娠のなかばごろ）。選んだあとで直せる。
    static func initialDate(today: CalendarDay) -> CalendarDay {
        today.adding(days: 140)
    }
}

/// 妊娠週数を画面に出すかどうかと、出す文（要件定義 v0.4 の 5.5）。
nonisolated enum GestationalAgeDisplay {
    /// その日の週数の文。出産予定日がない・範囲の外・「妊娠週数を表示する」がオフなら `nil`（R-50、R-53）。
    static func text(on day: CalendarDay, dueDate: CalendarDay?, isShown: Bool) -> String? {
        guard isShown, let dueDate, let age = GestationalAge(on: day, dueDate: dueDate) else {
            return nil
        }
        return age.text
    }

    /// これまでの健診後メモの週数の文。記録したときの予定日で計算した週数を使う（R-52）。
    static func text(for age: GestationalAge?, isShown: Bool) -> String? {
        isShown ? age?.text : nil
    }
}
