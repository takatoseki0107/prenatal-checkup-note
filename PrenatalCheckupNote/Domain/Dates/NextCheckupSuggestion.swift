import Foundation

/// 次の健診の日付の目安。要件定義 v0.4 R-30。
///
/// 目安は「保存」を押すまで予定にしない（R-31）。実際の日付は病院で決まるので、画面では理由とともに見せる。
nonisolated struct NextCheckupSuggestion: Hashable, Sendable {
    /// 目安の理由。画面で「前回の健診（妊娠 20 週）から 4 週間後」のように説明するために使う。
    nonisolated enum Reason: Hashable, Sendable {
        /// 出産予定日があり、基準の日の週数から標準の間隔で数えた。
        case standardInterval(at: GestationalAge)
        /// 出産予定日がなく、直近 2 回の受診日の間隔で数えた。
        case sameAsLastInterval
        /// 手がかりがなく、2 週間で数えた。
        case defaultInterval
    }

    /// 間隔の日数の範囲（R-30）。直近 2 回の間隔がこの外なら、範囲に収める。
    static let intervalRange = 7...35

    /// 手がかりがないときの間隔（日）。
    static let defaultIntervalDays = 14

    let day: CalendarDay
    let intervalDays: Int
    let reason: Reason
    /// 数え始めた日。前回の健診の受診日、またはそれがない・目安が今日より前になるときは今日。
    let baseDay: CalendarDay

    /// 標準の受診間隔（日）。23 週まで 4 週、24〜35 週 2 週、36 週から 1 週。
    static func standardIntervalDays(for age: GestationalAge) -> Int {
        switch age.weeks {
        case ...23: 28
        case 24...35: 14
        default: 7
        }
    }

    /// - Parameters:
    ///   - visitDays: これまでの健診後メモの受診日。順番と重なりは問わない。
    ///   - dueDate: 出産予定日。なければ `nil`。
    ///   - today: 今日。
    static func make(visitDays: [CalendarDay], dueDate: CalendarDay?, today: CalendarDay) -> NextCheckupSuggestion {
        let distinctDays = Set(visitDays).sorted()
        let lastVisit = distinctDays.last

        let (intervalDays, reason) = interval(
            distinctDays: distinctDays,
            dueDate: dueDate,
            base: lastVisit ?? today
        )

        if let lastVisit {
            let candidate = lastVisit.adding(days: intervalDays)
            if candidate >= today {
                return NextCheckupSuggestion(day: candidate, intervalDays: intervalDays, reason: reason, baseDay: lastVisit)
            }
        }

        // 前回の健診がない、または目安が今日より前になるときは、今日から数える。
        return NextCheckupSuggestion(day: today.adding(days: intervalDays), intervalDays: intervalDays, reason: reason, baseDay: today)
    }

    private static func interval(distinctDays: [CalendarDay], dueDate: CalendarDay?, base: CalendarDay) -> (Int, Reason) {
        if let dueDate, let age = GestationalAge(on: base, dueDate: dueDate) {
            return (standardIntervalDays(for: age), .standardInterval(at: age))
        }
        if distinctDays.count >= 2 {
            let last = distinctDays[distinctDays.count - 1]
            let previous = distinctDays[distinctDays.count - 2]
            let gap = previous.days(until: last)
            let clamped = min(max(gap, intervalRange.lowerBound), intervalRange.upperBound)
            return (clamped, .sameAsLastInterval)
        }
        return (defaultIntervalDays, .defaultInterval)
    }
}
