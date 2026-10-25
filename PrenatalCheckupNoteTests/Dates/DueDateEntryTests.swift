import Testing
@testable import PrenatalCheckupNote

/// 出産予定日の入力と、妊娠週数を出すかどうか（R-50〜R-53）を確かめる。
struct DueDateEntryTests {
    private let today = TestDates.day(2026, 10, 25)

    @Test func usesTheChosenDateInDateMode() {
        var entry = DueDateEntry()
        #expect(entry.dueDate(today: today) == nil)

        entry.date = TestDates.day(2027, 3, 1)
        #expect(entry.dueDate(today: today) == TestDates.day(2027, 3, 1))
    }

    @Test func calculatesFromTheCurrentWeeks() {
        // 今日が 20 週 0 日なら、予定日は 140 日後。
        var entry = DueDateEntry(mode: .weeks)
        #expect(entry.dueDate(today: today) == nil)

        entry.weeks = 20
        entry.days = 0
        #expect(entry.dueDate(today: today) == today.adding(days: 140))

        entry.days = 3
        #expect(entry.dueDate(today: today) == today.adding(days: 137))
    }

    @Test func startsTheDatePickerTwentyWeeksAhead() {
        #expect(DueDateEntry.initialDate(today: today) == today.adding(days: 140))
    }

    @Test func showsTheWeeksOnlyWhenAskedAndInRange() {
        let dueDate = today.adding(days: 140)

        #expect(GestationalAgeDisplay.text(on: today, dueDate: dueDate, isShown: true) == "妊娠 20 週 0 日")
        #expect(GestationalAgeDisplay.text(on: today, dueDate: dueDate, isShown: false) == nil)
        #expect(GestationalAgeDisplay.text(on: today, dueDate: nil, isShown: true) == nil)
        // 範囲の外（44 週 0 日より後）は出さない。
        #expect(GestationalAgeDisplay.text(on: today, dueDate: today.adding(days: -29), isShown: true) == nil)
    }

    @Test func hidesThePastMemoWeeksWhenTurnedOff() throws {
        let age = try #require(GestationalAge(totalDays: 170))
        #expect(GestationalAgeDisplay.text(for: age, isShown: true) == "妊娠 24 週 2 日")
        #expect(GestationalAgeDisplay.text(for: age, isShown: false) == nil)
        #expect(GestationalAgeDisplay.text(for: nil, isShown: true) == nil)
    }
}
