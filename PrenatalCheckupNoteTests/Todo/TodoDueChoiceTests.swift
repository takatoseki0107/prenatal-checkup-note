import Foundation
import Testing
@testable import PrenatalCheckupNote

/// やることの期限のボタン（要件定義 v0.4 R-102）を確かめる。今日は 2026 年 10 月 27 日（火）。
struct TodoDueChoiceTests {
    private let today = TestDates.day(2026, 10, 27)
    private let nextCheckup = TestDates.day(2026, 11, 9)

    @Test func showsTheNextCheckupButtonOnlyWithAnUpcomingCheckup() {
        #expect(TodoDueChoice.available(today: today, nextCheckupDay: nextCheckup) == [.noDue, .today, .tomorrow, .nextCheckup, .oneWeek, .pickDate])
        #expect(TodoDueChoice.available(today: today, nextCheckupDay: today).contains(.nextCheckup))
        #expect(TodoDueChoice.available(today: today, nextCheckupDay: nil) == [.noDue, .today, .tomorrow, .oneWeek, .pickDate])
        #expect(!TodoDueChoice.available(today: today, nextCheckupDay: TestDates.day(2026, 10, 26)).contains(.nextCheckup))
    }

    @Test func labelsTheButtons() {
        let labels = TodoDueChoice.available(today: today, nextCheckupDay: nextCheckup).map { $0.label(nextCheckupDay: nextCheckup) }
        #expect(labels == ["期限なし", "今日", "明日", "次の健診まで（11月9日）", "1 週間後", "日付を選ぶ"])
    }

    @Test func turnsEachButtonIntoAFixedDay() {
        func day(_ choice: TodoDueChoice, picked: CalendarDay? = nil) -> CalendarDay? {
            choice.dueDay(today: today, nextCheckupDay: nextCheckup, pickedDay: picked)
        }
        let picked = TestDates.day(2026, 12, 1)

        #expect(day(.noDue) == nil)
        #expect(day(.today) == today)
        #expect(day(.tomorrow) == TestDates.day(2026, 10, 28))
        #expect(day(.nextCheckup) == nextCheckup)
        #expect(day(.oneWeek) == TestDates.day(2026, 11, 3))
        #expect(day(.pickDate) == nil)
        #expect(day(.pickDate, picked: picked) == picked)
    }

    @Test func summarizesTheChosenDue() {
        func summary(_ choice: TodoDueChoice, picked: CalendarDay? = nil) -> String {
            choice.summary(today: today, nextCheckupDay: nextCheckup, pickedDay: picked)
        }

        #expect(summary(.noDue) == "期限なし")
        #expect(summary(.today) == "期限：10月27日（火）まで")
        #expect(summary(.nextCheckup) == "期限：11月9日（月）まで")
        #expect(summary(.pickDate) == "下のカレンダーで日付を選んでください")
        #expect(summary(.pickDate, picked: TestDates.day(2026, 12, 1)) == "期限：12月1日（火）まで")
    }

    @Test func needsATitleAndAPickedDate() {
        #expect(TodoDueChoice.noDue.canSave(title: "母親学級の申し込み", pickedDay: nil))
        #expect(!TodoDueChoice.noDue.canSave(title: " \u{3000}\n", pickedDay: nil))
        #expect(!TodoDueChoice.pickDate.canSave(title: "母親学級の申し込み", pickedDay: nil))
        #expect(TodoDueChoice.pickDate.canSave(title: "母親学級の申し込み", pickedDay: today))
    }

    @Test func choosesTheButtonWhenEditing() {
        func initial(_ due: CalendarDay?, next: CalendarDay? = TestDates.day(2026, 11, 9)) -> TodoDueChoice {
            TodoDueChoice.initial(for: due, today: today, nextCheckupDay: next)
        }

        #expect(initial(nil) == .noDue)
        #expect(initial(today) == .today)
        #expect(initial(TestDates.day(2026, 10, 28)) == .tomorrow)
        #expect(initial(TestDates.day(2026, 11, 3)) == .oneWeek)
        #expect(initial(nextCheckup) == .nextCheckup)
        #expect(initial(TestDates.day(2026, 12, 1)) == .pickDate)
        #expect(initial(TestDates.day(2026, 10, 20)) == .pickDate)
        // 次の健診の日付がなくなっていたら、その日は「日付を選ぶ」で選んだ状態にする。
        #expect(initial(nextCheckup, next: nil) == .pickDate)
    }
}
