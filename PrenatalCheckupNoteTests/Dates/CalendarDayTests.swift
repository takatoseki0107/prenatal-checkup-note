import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 時刻を持たない日付（R-90、R-91）を確かめる。
struct CalendarDayTests {
    @Test func showsMonthDayAndWeekdayInJapanese() {
        // 2026-10-25 は日曜日、2026-11-05 は木曜日、2027-01-01 は金曜日。
        #expect(TestDates.day(2026, 10, 25).displayText == "10月25日（日）")
        #expect(TestDates.day(2026, 11, 5).displayText == "11月5日（木）")
        #expect(TestDates.day(2027, 1, 1).displayText == "1月1日（金）")
    }

    @Test func makesOnlyRealDays() {
        #expect(CalendarDay(year: 2026, month: 2, day: 30) == nil)
        #expect(CalendarDay(year: 2026, month: 13, day: 1) == nil)
        #expect(CalendarDay(year: 2028, month: 2, day: 29) != nil)
    }

    @Test func readsTheDayInJapanTimeWhateverTheMomentIs() throws {
        // 日本時間の 2026-10-25 00:30 は、協定世界時では 10-24 15:30。日本時間の日付になること。
        let justAfterMidnight = TestDates.tokyo(2026, 10, 25, 0, 30)
        #expect(CalendarDay(justAfterMidnight) == TestDates.day(2026, 10, 25))

        let justBeforeMidnight = TestDates.tokyo(2026, 10, 25, 23, 59)
        #expect(CalendarDay(justBeforeMidnight) == TestDates.day(2026, 10, 25))

        // 協定世界時の暦で読むと、同じ瞬間が前の日になる。日本時間に固定している意味の確認。
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(CalendarDay(justAfterMidnight, calendar: utc) == TestDates.day(2026, 10, 24))
    }

    @Test func addsDaysAcrossMonthsAndYears() {
        #expect(TestDates.day(2026, 12, 31).adding(days: 1) == TestDates.day(2027, 1, 1))
        #expect(TestDates.day(2026, 3, 1).adding(days: -1) == TestDates.day(2026, 2, 28))
        #expect(TestDates.day(2026, 10, 25).adding(days: 0) == TestDates.day(2026, 10, 25))
    }

    @Test func countsDaysBetween() {
        let start = TestDates.day(2026, 10, 25)
        let end = TestDates.day(2026, 11, 5)

        #expect(start.days(until: end) == 11)
        #expect(end.days(until: start) == -11)
        #expect(start.days(until: start) == 0)
    }

    @Test func ordersAndPrintsDays() {
        #expect(TestDates.day(2026, 10, 25) < TestDates.day(2026, 10, 26))
        #expect(TestDates.day(2026, 12, 31) < TestDates.day(2027, 1, 1))
        #expect(TestDates.day(2026, 3, 5).description == "2026-03-05")
    }

    @Test func convertsToAndFromTheStoredNumber() {
        let day = TestDates.day(2026, 11, 5)

        #expect(day.number == 20_261_105)
        #expect(CalendarDay(number: 20_261_105) == day)
        #expect(CalendarDay(number: 20_260_230) == nil)
        #expect(TestDates.day(2026, 12, 31).number < TestDates.day(2027, 1, 1).number)
    }

    @Test func survivesEncodingAndDecoding() throws {
        let original = TestDates.day(2026, 11, 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CalendarDay.self, from: data)

        #expect(decoded == original)
    }
}
