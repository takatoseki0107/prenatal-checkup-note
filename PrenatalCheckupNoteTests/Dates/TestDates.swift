import Foundation
@testable import PrenatalCheckupNote

/// テストで使う日付と日時。日本時間で作る。
nonisolated enum TestDates {
    static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        guard let made = CalendarDay(year: year, month: month, day: day) else {
            fatalError("実在しない日付：\(year)-\(month)-\(day)")
        }
        return made
    }

    static func tokyo(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        self.day(year, month, day).date(hour: hour, minute: minute)
    }
}
