import Foundation

/// 健診予定のカードに出す、次の健診までの日数の文（2026-10-28 追加。キャンバスの見本 `NextCardLight.dc.html`）。
///
/// 開発者が見せてくれた画面の「次の健診まで、あと 14 日」を、いまの見た目に取り入れた。
/// 日付は暦の上の日数で数える（時刻は見ない）。今日・明日は、日数ではなく言葉で出す。
nonisolated enum CheckupCountdown {
    static func text(today: CalendarDay, checkupDay: CalendarDay) -> String {
        let days = today.days(until: checkupDay)
        switch days {
        case ..<0:
            // 健診後メモを書くと次の健診の欄は空になるので、ふつうは出ない。書かずに日がたったとき。
            return "健診の日を過ぎました"
        case 0:
            return "今日は健診の日です"
        case 1:
            return "明日は健診の日です"
        default:
            return "次の健診まで、あと \(days) 日"
        }
    }
}
