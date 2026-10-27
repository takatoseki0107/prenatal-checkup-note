import Foundation
import Testing
@testable import PrenatalCheckupNote

/// やることの一覧の並べ方と数え方（要件定義 v0.4 の 5.10）を確かめる。
///
/// 今日は 2026 年 10 月 27 日（火）、次の健診は 11 月 9 日（月）とする。
struct TodoListTests {
    private let today = TestDates.day(2026, 10, 27)
    private let nextCheckup = TestDates.day(2026, 11, 9)

    /// 足した順を決めるための日時。`minutes` が小さいほど先に足した。
    private func added(_ minutes: Int) -> Date {
        TestDates.tokyo(2026, 10, 20, 9, 0).addingTimeInterval(TimeInterval(minutes * 60))
    }

    private func entry(
        _ title: String,
        due: CalendarDay? = nil,
        starred: Bool = false,
        checked: Bool = false,
        completedAt: Date? = nil,
        origin: CalendarDay? = nil,
        added minutes: Int = 0
    ) -> TodoList.Entry {
        TodoList.Entry(
            title: title,
            dueDay: due,
            isStarred: starred,
            isChecked: checked,
            completedAt: completedAt,
            originVisitDay: origin,
            createdAt: added(minutes)
        )
    }

    private func days(_ offset: Int) -> CalendarDay {
        today.adding(days: offset)
    }

    // MARK: - 並べ方（R-103）

    @Test func putsNoDueFirstThenOverdueThenEachDay() {
        let entries = [
            entry("明日", due: days(1), added: 1),
            entry("期限なし", added: 2),
            entry("過ぎた", due: days(-2), added: 3),
            entry("今日", due: today, added: 4),
            entry("次の健診の日", due: nextCheckup, added: 5),
            entry("その先", due: days(20), added: 6),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckup)

        #expect(sections.map(\.title) == ["期限なし", "期限を過ぎた", "今日", "明日", "11月9日（月）", "11月16日（月）"])
        #expect(sections.map(\.subtitle) == [nil, nil, "10月27日（火）", "10月28日（水）", "次の健診の日", nil])
        #expect(sections.map { $0.entries.map(\.title) } == [["期限なし"], ["過ぎた"], ["今日"], ["明日"], ["次の健診の日"], ["その先"]])
        #expect(sections[4].kind == .day(nextCheckup, isNextCheckupDay: true))
    }

    @Test func putsStarredFirstThenTheOrderAdded() {
        let entries = [
            entry("A", due: days(3), added: 1),
            entry("B", due: days(3), starred: true, added: 2),
            entry("C", due: days(3), added: 3),
            entry("D", due: days(3), starred: true, added: 4),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nil)

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.title) == ["B", "D", "A", "C"])
    }

    @Test func sortsOverdueByStarThenOldestDue() {
        let entries = [
            entry("3 日前", due: days(-3), added: 1),
            entry("1 日前", due: days(-1), added: 2),
            entry("5 日前", due: days(-5), added: 3),
            entry("星の 1 日前", due: days(-1), starred: true, added: 4),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nil)

        #expect(sections.map(\.kind) == [.overdue])
        #expect(sections[0].entries.map(\.title) == ["星の 1 日前", "5 日前", "3 日前", "1 日前"])
    }

    @Test func leavesOutCompletedTodos() {
        let entries = [
            entry("残る", due: today, added: 1),
            entry("完了", due: today, completedAt: added(10), added: 2),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nil)

        #expect(sections.flatMap(\.entries).map(\.title) == ["残る"])
    }

    @Test func keepsCheckedTodosInPlace() {
        let entries = [
            entry("A", due: today, added: 1),
            entry("B", due: today, checked: true, added: 2),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nil)

        #expect(sections[0].entries.map(\.title) == ["A", "B"])
    }

    @Test func returnsNothingForAnEmptyList() {
        #expect(TodoList.sections([], today: today, nextCheckupDay: nextCheckup).isEmpty)
    }

    // MARK: - 次の健診の線（R-103）

    @Test func drawsTheNextCheckupLineBetweenDays() {
        let entries = [
            entry("明日", due: days(1)),
            entry("その先", due: days(20)),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckup)

        #expect(sections.map(\.title) == ["明日", "11月9日（月）は次の健診", "11月16日（月）"])
        #expect(sections[1].kind == .nextCheckupLine(nextCheckup))
        #expect(sections[1].entries.isEmpty)
    }

    @Test func drawsTheNextCheckupLineAtTheEndWhenEveryDayIsBefore() {
        let entries = [entry("明日", due: days(1))]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckup)

        #expect(sections.map(\.title) == ["明日", "11月9日（月）は次の健診"])
    }

    @Test func drawsNoLineWhenTheDayHasTodos() {
        let entries = [entry("次の健診の日", due: nextCheckup)]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckup)

        #expect(sections.map(\.kind) == [.day(nextCheckup, isNextCheckupDay: true)])
    }

    @Test func drawsNoLineWithoutDatedTodos() {
        let entries = [
            entry("期限なし"),
            entry("過ぎた", due: days(-1)),
        ]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nextCheckup)

        #expect(sections.map(\.kind) == [.noDue, .overdue])
    }

    @Test func drawsNoLineForAPastOrMissingNextCheckup() {
        let entries = [entry("明日", due: days(1))]

        #expect(TodoList.sections(entries, today: today, nextCheckupDay: nil).map(\.title) == ["明日"])
        #expect(TodoList.sections(entries, today: today, nextCheckupDay: days(-1)).map(\.title) == ["明日"])
    }

    @Test func marksTodayWhenTheNextCheckupIsToday() {
        let entries = [entry("今日", due: today)]

        let sections = TodoList.sections(entries, today: today, nextCheckupDay: today)

        #expect(sections.map(\.title) == ["今日"])
        #expect(sections.map(\.subtitle) == ["10月27日（火）　次の健診の日"])
    }

    // MARK: - 完了したこと（R-104）

    @Test func listsCompletedTodosNewestFirst() {
        let entries = [
            entry("先に完了", completedAt: added(10), added: 1),
            entry("まだ", added: 2),
            entry("あとで完了", completedAt: added(20), added: 3),
        ]

        #expect(TodoList.completed(entries).map(\.title) == ["あとで完了", "先に完了"])
        #expect(TodoList.completedTitle(count: 2) == "完了したこと（2 件）")
    }

    @Test func countsCheckedTodos() {
        let entries = [
            entry("A", checked: true),
            entry("B"),
            entry("C", checked: true),
            entry("完了", checked: true, completedAt: added(5)),
        ]

        #expect(TodoList.checkedCount(entries) == 2)
        #expect(TodoList.completeButtonTitle(checkedCount: 2) == "チェックした 2 件を完了にする")
    }

    // MARK: - タブの数（R-106）

    @Test func countsOverdueAndTodayForTheTab() {
        let entries = [
            entry("過ぎた", due: days(-1)),
            entry("今日", due: today),
            entry("明日", due: days(1)),
            entry("期限なし"),
            entry("完了した今日", due: today, completedAt: added(5)),
        ]

        #expect(TodoList.badgeCount(entries, today: today) == 2)
    }

    // MARK: - 健診予定のカードの 1 行（R-110）

    @Test func countsTodosUntilTheNextCheckup() throws {
        let entries = [
            entry("過ぎた", due: days(-2)),
            entry("今日", due: today),
            entry("次の健診の日", due: nextCheckup),
            entry("次の健診の日（星）", due: nextCheckup, starred: true),
            entry("その先", due: days(20)),
            entry("期限なし"),
            entry("完了", due: today, completedAt: added(5)),
        ]

        let summary = try #require(TodoList.nextCheckupSummary(entries, today: today, nextCheckupDay: nextCheckup))

        #expect(summary == TodoList.NextCheckupSummary(count: 4, overdueCount: 1))
        #expect(summary.title == "次の健診までのやること　4 件")
        #expect(summary.overdueText == "期限を過ぎたもの 1 件")
    }

    @Test func hidesTheOverdueTextWhenNothingIsOverdue() throws {
        let entries = [entry("今日", due: today)]

        let summary = try #require(TodoList.nextCheckupSummary(entries, today: today, nextCheckupDay: nextCheckup))

        #expect(summary.overdueText == nil)
    }

    @Test func hidesTheSummaryWithoutANextCheckupOrTodos() {
        let entries = [
            entry("その先", due: days(20)),
            entry("期限なし"),
        ]

        #expect(TodoList.nextCheckupSummary([entry("今日", due: today)], today: today, nextCheckupDay: nil) == nil)
        #expect(TodoList.nextCheckupSummary(entries, today: today, nextCheckupDay: nextCheckup) == nil)
    }

    // MARK: - 次の健診までに絞る（R-111）

    @Test func narrowsToTodosUntilTheNextCheckup() {
        let entries = [
            entry("過ぎた", due: days(-2), added: 1),
            entry("今日", due: today, added: 2),
            entry("次の健診の日", due: nextCheckup, added: 3),
            entry("その先", due: days(20), added: 4),
            entry("期限なし", added: 5),
            entry("完了", due: today, completedAt: added(10), added: 6),
        ]

        let narrowed = TodoList.untilNextCheckup(entries, nextCheckupDay: nextCheckup)
        let sections = TodoList.sections(narrowed, today: today, nextCheckupDay: nextCheckup)

        #expect(narrowed.map(\.title) == ["過ぎた", "今日", "次の健診の日"])
        #expect(sections.map(\.title) == ["期限を過ぎた", "今日", "11月9日（月）"])
        #expect(TodoList.untilNextCheckupTitle(nextCheckupDay: nextCheckup) == "次の健診（11月9日）までのやること")
        // 完了したものは「ほか」に数えない。
        #expect(TodoList.showOthersButtonTitle(entries, nextCheckupDay: nextCheckup) == "ほかのやること（2 件）も表示")
    }

    @Test func saysBackToTheListWhenThereAreNoOthers() {
        let entries = [
            entry("今日", due: today),
            entry("完了", completedAt: added(10)),
        ]

        #expect(TodoList.showOthersButtonTitle(entries, nextCheckupDay: nextCheckup) == "やることの一覧に戻る")
    }

    // MARK: - 行の文（R-103、R-107）

    @Test func showsTheDueDateOnlyForOverdueRows() {
        #expect(TodoList.rowDueText(entry("過ぎた", due: days(-2)), today: today) == "10月25日（日）まで（過ぎています）")
        #expect(TodoList.rowDueText(entry("今日", due: today), today: today) == nil)
        #expect(TodoList.rowDueText(entry("期限なし"), today: today) == nil)
        #expect(TodoList.rowDueText(entry("完了", due: days(-2), completedAt: added(5)), today: today) == nil)
    }

    @Test func showsWhichCheckupTheTodoCameFrom() {
        #expect(TodoList.originText(entry("受診票", origin: TestDates.day(2026, 10, 12))) == "10月12日の健診で")
        #expect(TodoList.originText(entry("自分で足した")) == nil)
    }
}
