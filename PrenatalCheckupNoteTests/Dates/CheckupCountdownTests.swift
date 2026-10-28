import Testing
@testable import PrenatalCheckupNote

/// 健診予定のカードの、次の健診までの日数の文を確かめる。
struct CheckupCountdownTests {
    private let today = CalendarDay(year: 2026, month: 10, day: 28)!

    @Test func countsTheDaysUntilTheCheckup() {
        #expect(CheckupCountdown.text(today: today, checkupDay: CalendarDay(year: 2026, month: 11, day: 11)!) == "次の健診まで、あと 14 日")
        #expect(CheckupCountdown.text(today: today, checkupDay: CalendarDay(year: 2026, month: 10, day: 30)!) == "次の健診まで、あと 2 日")
    }

    @Test func saysTodayAndTomorrowInWords() {
        #expect(CheckupCountdown.text(today: today, checkupDay: today) == "今日は健診の日です")
        #expect(CheckupCountdown.text(today: today, checkupDay: CalendarDay(year: 2026, month: 10, day: 29)!) == "明日は健診の日です")
    }

    @Test func saysWhenTheDayHasPassed() {
        #expect(CheckupCountdown.text(today: today, checkupDay: CalendarDay(year: 2026, month: 10, day: 27)!) == "健診の日を過ぎました")
    }

    /// 大きな日付の下の曜日。2026 年 11 月 11 日は水曜日。
    @Test func namesTheWeekday() {
        #expect(CalendarDay(year: 2026, month: 11, day: 11)!.weekdayName == "水曜日")
        #expect(CalendarDay(year: 2026, month: 11, day: 11)!.displayText == "11月11日（水）")
    }
}
