import Testing
@testable import PrenatalCheckupNote

/// 妊娠週数（R-50）を確かめる。
struct GestationalAgeTests {
    private let dueDate = TestDates.day(2027, 3, 1)

    @Test func isFortyWeeksOnTheDueDate() throws {
        let age = try #require(GestationalAge(on: dueDate, dueDate: dueDate))

        #expect(age.totalDays == 280)
        #expect(age.weeks == 40)
        #expect(age.days == 0)
    }

    @Test func showsOnlyFromZeroToFortyFourWeeks() {
        #expect(GestationalAge(on: dueDate.adding(days: -280), dueDate: dueDate)?.totalDays == 0)
        #expect(GestationalAge(on: dueDate.adding(days: -281), dueDate: dueDate) == nil)
        #expect(GestationalAge(on: dueDate.adding(days: 28), dueDate: dueDate)?.totalDays == 308)
        #expect(GestationalAge(on: dueDate.adding(days: 29), dueDate: dueDate) == nil)
    }

    @Test func splitsIntoWeeksAndDays() throws {
        let age = try #require(GestationalAge(totalDays: 171))

        #expect(age.weeks == 24)
        #expect(age.days == 3)
        #expect(age.text == "妊娠 24 週 3 日")
    }

    @Test func findsTheDueDateFromTodaysWeeks() throws {
        let today = TestDates.day(2026, 10, 25)
        let calculated = try #require(GestationalAge.dueDate(weeks: 20, days: 3, today: today))

        #expect(calculated == today.adding(days: 280 - 143))
        #expect(GestationalAge(on: today, dueDate: calculated)?.totalDays == 143)
    }

    @Test func refusesWeeksAndDaysOutOfRange() {
        let today = TestDates.day(2026, 10, 25)

        #expect(GestationalAge.dueDate(weeks: 45, days: 0, today: today) == nil)
        #expect(GestationalAge.dueDate(weeks: 44, days: 1, today: today) == nil)
        #expect(GestationalAge.dueDate(weeks: 10, days: 7, today: today) == nil)
        #expect(GestationalAge.dueDate(weeks: -1, days: 0, today: today) == nil)
    }
}
