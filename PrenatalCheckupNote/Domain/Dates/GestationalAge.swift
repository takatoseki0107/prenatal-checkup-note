import Foundation

/// 妊娠週数。出産予定日を 40 週 0 日（280 日）として数える。要件定義 v0.4 R-50。
nonisolated struct GestationalAge: Hashable, Comparable, Sendable {
    /// 表示する範囲。0 日以上 308 日以下（0 週 0 日〜44 週 0 日）。外れたら出さない。
    static let displayRange = 0...308

    /// 出産予定日の日数（40 週 0 日）。
    static let daysAtDueDate = 280

    /// 妊娠 0 週 0 日から数えた日数。
    let totalDays: Int

    var weeks: Int { totalDays / 7 }
    var days: Int { totalDays % 7 }

    /// 範囲の中のときだけ作れる。
    init?(totalDays: Int) {
        guard Self.displayRange.contains(totalDays) else {
            return nil
        }
        self.totalDays = totalDays
    }

    /// その日の妊娠週数。範囲の外なら `nil`。
    init?(on day: CalendarDay, dueDate: CalendarDay) {
        self.init(totalDays: Self.daysAtDueDate - day.days(until: dueDate))
    }

    /// 「いまの週数から計算する」（はじめに）で使う。今日が `weeks` 週 `days` 日のときの出産予定日。
    ///
    /// 週は 0〜44、日は 0〜6 のときだけ計算する。
    static func dueDate(weeks: Int, days: Int, today: CalendarDay) -> CalendarDay? {
        guard (0...44).contains(weeks), (0...6).contains(days),
              let age = GestationalAge(totalDays: weeks * 7 + days) else {
            return nil
        }
        return today.adding(days: daysAtDueDate - age.totalDays)
    }

    static func < (lhs: GestationalAge, rhs: GestationalAge) -> Bool {
        lhs.totalDays < rhs.totalDays
    }

    /// 例：「妊娠 24 週 3 日」。
    var text: String {
        "妊娠 \(weeks) 週 \(days) 日"
    }
}
