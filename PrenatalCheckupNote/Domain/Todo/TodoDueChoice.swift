import Foundation

/// やることの期限のボタン（要件定義 v0.4 R-102）。足す・直すシートで使う。
///
/// どのボタンでも、期限には選んだときの日付をそのまま入れる。あとで次の健診の日付を変えても、期限は動かさない（ADR 0012）。
nonisolated enum TodoDueChoice: Hashable, Sendable {
    case noDue
    case today
    case tomorrow
    /// 次の健診の日まで。次の健診の日付が今日以降のときだけ出す。
    case nextCheckup
    case oneWeek
    /// 「日付を選ぶ」（カレンダー）。日付を選ぶまでは、追加・保存できない。
    case pickDate

    /// 出すボタン。次の健診の日付がない（または過ぎている）ときは「次の健診まで」を出さない。
    static func available(today: CalendarDay, nextCheckupDay: CalendarDay?) -> [TodoDueChoice] {
        var choices: [TodoDueChoice] = [.noDue, .today, .tomorrow]
        if hasUpcomingCheckup(today: today, nextCheckupDay: nextCheckupDay) {
            choices.append(.nextCheckup)
        }
        choices.append(contentsOf: [.oneWeek, .pickDate])
        return choices
    }

    /// ボタンの文。例：「次の健診まで（11月9日）」。
    func label(nextCheckupDay: CalendarDay?) -> String {
        switch self {
        case .noDue:
            "期限なし"
        case .today:
            "今日"
        case .tomorrow:
            "明日"
        case .nextCheckup:
            nextCheckupDay.map { "次の健診まで（\($0.month)月\($0.day)日）" } ?? "次の健診まで"
        case .oneWeek:
            "1 週間後"
        case .pickDate:
            "日付を選ぶ"
        }
    }

    /// 選んだボタンから決まる期限の日。期限なし、または「日付を選ぶ」でまだ選んでいなければ `nil`。
    func dueDay(today: CalendarDay, nextCheckupDay: CalendarDay?, pickedDay: CalendarDay?) -> CalendarDay? {
        switch self {
        case .noDue:
            nil
        case .today:
            today
        case .tomorrow:
            today.adding(days: 1)
        case .nextCheckup:
            nextCheckupDay
        case .oneWeek:
            today.adding(days: 7)
        case .pickDate:
            pickedDay
        }
    }

    /// 「日付を選ぶ」を押して、まだ日付を選んでいないか。このときは追加・保存できない。
    func isWaitingForDate(pickedDay: CalendarDay?) -> Bool {
        self == .pickDate && pickedDay == nil
    }

    /// ボタンの下に出す、選んだ期限の文。例：「期限：11月9日（月）まで」。
    func summary(today: CalendarDay, nextCheckupDay: CalendarDay?, pickedDay: CalendarDay?) -> String {
        if isWaitingForDate(pickedDay: pickedDay) {
            return "下のカレンダーで日付を選んでください"
        }
        guard let day = dueDay(today: today, nextCheckupDay: nextCheckupDay, pickedDay: pickedDay) else {
            return "期限なし"
        }
        return "期限：\(day.displayText)まで"
    }

    /// 追加・保存できるか。やることの文が必須で、「日付を選ぶ」なら日付も要る。
    func canSave(title: String, pickedDay: CalendarDay?) -> Bool {
        InputText.normalized(title) != nil && !isWaitingForDate(pickedDay: pickedDay)
    }

    /// 直すシートを開いたときに選んでおくボタン。期限の日から決める。
    ///
    /// 次の健診の日と同じなら「次の健診まで」、今日・明日・1 週間後ならそのボタン、どれでもなければ「日付を選ぶ」（その日を選んだ状態）。
    static func initial(for dueDay: CalendarDay?, today: CalendarDay, nextCheckupDay: CalendarDay?) -> TodoDueChoice {
        guard let dueDay else {
            return .noDue
        }
        if hasUpcomingCheckup(today: today, nextCheckupDay: nextCheckupDay), dueDay == nextCheckupDay {
            return .nextCheckup
        }
        switch today.days(until: dueDay) {
        case 0:
            return .today
        case 1:
            return .tomorrow
        case 7:
            return .oneWeek
        default:
            return .pickDate
        }
    }

    private static func hasUpcomingCheckup(today: CalendarDay, nextCheckupDay: CalendarDay?) -> Bool {
        guard let nextCheckupDay else {
            return false
        }
        return nextCheckupDay >= today
    }
}
