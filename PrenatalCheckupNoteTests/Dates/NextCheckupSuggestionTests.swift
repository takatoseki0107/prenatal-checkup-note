import Testing
@testable import PrenatalCheckupNote

/// 次の健診の日付の目安（R-30）を確かめる。
struct NextCheckupSuggestionTests {
    private let today = TestDates.day(2026, 10, 25)

    @Test(arguments: [
        (23, 28),
        (24, 14),
        (35, 14),
        (36, 7),
        (40, 7),
    ])
    func usesTheStandardInterval(weeks: Int, expectedDays: Int) throws {
        let age = try #require(GestationalAge(totalDays: weeks * 7))

        #expect(NextCheckupSuggestion.standardIntervalDays(for: age) == expectedDays)
    }

    @Test func countsFromTheLastVisitWithTheDueDate() throws {
        // 前回の健診（10 月 20 日）が妊娠 20 週 0 日になる出産予定日。
        let lastVisit = TestDates.day(2026, 10, 20)
        let dueDate = lastVisit.adding(days: 280 - 140)

        let ageAtLastVisit = try #require(GestationalAge(totalDays: 140))

        let suggestion = NextCheckupSuggestion.make(visitDays: [lastVisit], dueDate: dueDate, today: today)

        #expect(suggestion.day == lastVisit.adding(days: 28))
        #expect(suggestion.baseDay == lastVisit)
        #expect(suggestion.reason == .standardInterval(at: ageAtLastVisit))
    }

    @Test func usesTheLastTwoDistinctVisitsWithoutTheDueDate() {
        let visits = [
            TestDates.day(2026, 9, 1),
            TestDates.day(2026, 10, 20),
            TestDates.day(2026, 10, 6),
            TestDates.day(2026, 10, 20),
        ]

        let suggestion = NextCheckupSuggestion.make(visitDays: visits, dueDate: nil, today: today)

        // 同じ日の重なりは 1 回と数え、直近 2 回（10 月 6 日と 20 日）の 14 日で数える。
        #expect(suggestion.intervalDays == 14)
        #expect(suggestion.reason == .sameAsLastInterval)
        #expect(suggestion.day == TestDates.day(2026, 11, 3))
    }

    @Test(arguments: [
        (3, 7),
        (60, 35),
    ])
    func keepsTheLastIntervalInRange(gap: Int, expectedDays: Int) {
        let last = TestDates.day(2026, 10, 24)
        let visits = [last.adding(days: -gap), last]

        let suggestion = NextCheckupSuggestion.make(visitDays: visits, dueDate: nil, today: today)

        #expect(suggestion.intervalDays == expectedDays)
    }

    @Test func usesTwoWeeksWithOnlyOneVisit() {
        let lastVisit = TestDates.day(2026, 10, 20)

        let suggestion = NextCheckupSuggestion.make(visitDays: [lastVisit], dueDate: nil, today: today)

        #expect(suggestion.intervalDays == 14)
        #expect(suggestion.reason == .defaultInterval)
        #expect(suggestion.day == TestDates.day(2026, 11, 3))
    }

    @Test func countsFromTodayWithNoVisits() {
        let suggestion = NextCheckupSuggestion.make(visitDays: [], dueDate: nil, today: today)

        #expect(suggestion.day == today.adding(days: 14))
        #expect(suggestion.baseDay == today)
    }

    @Test func countsFromTodayWhenTheResultWouldBeInThePast() {
        // 前回が 9 月 1 日で間隔が 14 日だと 9 月 15 日になり、今日より前になる。
        let visits = [TestDates.day(2026, 8, 18), TestDates.day(2026, 9, 1)]

        let suggestion = NextCheckupSuggestion.make(visitDays: visits, dueDate: nil, today: today)

        #expect(suggestion.day == today.adding(days: 14))
        #expect(suggestion.baseDay == today)
    }

    @Test func keepsTheLastVisitWhenTheResultIsToday() {
        let visits = [TestDates.day(2026, 9, 27), TestDates.day(2026, 10, 11)]

        let suggestion = NextCheckupSuggestion.make(visitDays: visits, dueDate: nil, today: today)

        #expect(suggestion.day == today)
        #expect(suggestion.baseDay == TestDates.day(2026, 10, 11))
    }
}
