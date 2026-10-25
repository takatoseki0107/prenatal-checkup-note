import Foundation
import SwiftData
import Testing
@testable import PrenatalCheckupNote

/// 保存の窓口（要件定義 v0.4 の 5 章・7 章）を、一時的なファイルの保存場所で確かめる。
@MainActor
struct NoteServiceTests {
    private let now = TestDates.tokyo(2026, 11, 5, 11, 0)
    private let today = TestDates.day(2026, 11, 5)

    // MARK: - 聞きたいこと

    @Test func addsQuestionsToTheBottomTrimmed() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        try service.addQuestion(text: "  腰の痛みについて相談する\n", note: " 夕方に気になる ", now: now)
        try service.addQuestion(text: "仕事のこと", now: now)

        let questions = try service.questions()
        #expect(questions.map(\.text) == ["腰の痛みについて相談する", "仕事のこと"])
        #expect(questions.first?.note == "夕方に気になる")
    }

    @Test func refusesBlankQuestions() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        #expect(throws: NoteServiceError.emptyText) {
            try service.addQuestion(text: " \u{3000}\n", now: now)
        }
        #expect(try service.questions().isEmpty)
    }

    @Test func keepsTheOrderWhenAskedOrStarred() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let first = try service.addQuestion(text: "1", now: now)
        let second = try service.addQuestion(text: "2", now: now)
        let third = try service.addQuestion(text: "3", now: now)

        try service.setAsked(true, questionID: second)
        try service.setStarred(true, questionID: third)

        let questions = try service.questions()
        #expect(questions.map(\.id) == [first, second, third])
        #expect(questions.map(\.isAsked) == [false, true, false])
        #expect(questions.map(\.isStarred) == [false, false, true])
    }

    @Test func movesQuestions() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        for text in ["A", "B", "C"] {
            try service.addQuestion(text: text, now: now)
        }

        try service.moveQuestions(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(try service.questions().map(\.text) == ["C", "A", "B"])

        try service.moveQuestions(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(try service.questions().map(\.text) == ["A", "B", "C"])
    }

    @Test func deletesAQuestion() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addQuestion(text: "消す", now: now)

        try service.deleteQuestion(id: id)

        #expect(try service.questions().isEmpty)
        #expect(throws: NoteServiceError.notFound) {
            try service.deleteQuestion(id: id)
        }
    }

    // MARK: - 健診後メモ

    @Test func movesAskedQuestionsIntoTheMemoButKeepsExcludedOnes() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let asked = try service.addQuestion(text: "聞いた", now: now)
        let excluded = try service.addQuestion(text: "外した", now: now)
        let notAsked = try service.addQuestion(text: "まだ", now: now)
        try service.updateQuestion(id: asked, text: "聞いた", note: "補足", answer: "答え")
        try service.setAsked(true, questionID: asked)
        try service.setAsked(true, questionID: excluded)

        let result = try service.saveMemo(memoInput(excluded: [excluded]), now: now)

        let memo = try #require(try service.memo(id: result.memoID))
        #expect(memo.sortedItems.map(\.questionText) == ["聞いた"])
        #expect(memo.sortedItems.first?.answer == "答え")
        #expect(memo.sortedItems.first?.note == "補足")

        let remaining = try service.questions()
        #expect(remaining.map(\.id) == [excluded, notAsked])
        #expect(remaining.first?.isAsked == true)
    }

    @Test func refusesAMemoWithNothingInIt() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.addQuestion(text: "まだ聞いていない", now: now)

        #expect(throws: NoteServiceError.emptyMemo) {
            try service.saveMemo(memoInput(body: " \n"), now: now)
        }
        #expect(try service.memos().isEmpty)
    }

    @Test func savesAMemoWithOnlyTheBody() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        let result = try service.saveMemo(memoInput(body: "  次回は採血  "), now: now)

        let memo = try #require(try service.memo(id: result.memoID))
        #expect(memo.body == "次回は採血")
        #expect(memo.items.isEmpty)
        #expect(memo.visitDay == today)
    }

    @Test func savesOnlyOneMemoForTheSameID() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let input = memoInput(body: "メモ")

        let first = try service.saveMemo(input, now: now)
        let second = try service.saveMemo(input, now: now)

        #expect(!first.wasAlreadySaved)
        #expect(second.wasAlreadySaved)
        #expect(try service.memos().count == 1)
    }

    @Test func clearsTheNextCheckupWhenTheMemoIsForThatDay() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let nextID = try service.setNextCheckup(day: today, hour: 10, minute: 30, isReminderOn: true, reminderSlot: ReminderTimeRule.defaultSlot)
        let item = try #require(try service.bringItems().first)
        try service.setBringItemChecked(true, itemID: item.id)

        let result = try service.saveMemo(memoInput(body: "メモ", nextCheckupIDAtStart: nextID), now: now)

        #expect(result.clearedNextCheckup)
        #expect(try service.nextCheckup() == nil)
        #expect(try service.bringItems().allSatisfy { !$0.isChecked })
        #expect(try service.bringItems().count == NoteService.initialBringItemNames.count)
    }

    @Test func keepsTheNextCheckupForAnotherDay() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let nextID = try service.setNextCheckup(day: today.adding(days: 14), hour: 10, minute: 30, isReminderOn: false, reminderSlot: ReminderTimeRule.defaultSlot)

        let result = try service.saveMemo(memoInput(body: "メモ", nextCheckupIDAtStart: nextID), now: now)

        #expect(!result.clearedNextCheckup)
        #expect(try service.nextCheckup()?.id == nextID)
    }

    @Test func keepsANextCheckupThatReplacedTheOneAtTheStart() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let original = try service.setNextCheckup(day: today, hour: 10, minute: 30, isReminderOn: false, reminderSlot: ReminderTimeRule.defaultSlot)
        try service.clearNextCheckup()
        let replacement = try service.setNextCheckup(day: today, hour: 14, minute: 0, isReminderOn: false, reminderSlot: ReminderTimeRule.defaultSlot)

        let result = try service.saveMemo(memoInput(body: "メモ", nextCheckupIDAtStart: original), now: now)

        #expect(!result.clearedNextCheckup)
        #expect(try service.nextCheckup()?.id == replacement)
    }

    @Test func keepsTheDueDateUsedAtTheVisit() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let dueDate = today.adding(days: 280 - 170)
        try service.setDueDate(dueDate)

        let result = try service.saveMemo(memoInput(body: "メモ"), now: now)
        try service.setDueDate(dueDate.adding(days: 7))

        let memo = try #require(try service.memo(id: result.memoID))
        #expect(memo.dueDateNumberAtVisit == dueDate.number)
        #expect(memo.gestationalAgeAtVisit?.totalDays == 170)
    }

    // MARK: - 失敗と保持

    @Test func leavesNothingHalfSavedWhenTheMemoFailsToSave() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let asked = try service.addQuestion(text: "聞いた", now: now)
        try service.setAsked(true, questionID: asked)
        let nextID = try service.setNextCheckup(day: today, hour: 10, minute: 30, isReminderOn: true, reminderSlot: ReminderTimeRule.defaultSlot)
        let item = try #require(try service.bringItems().first)
        try service.setBringItemChecked(true, itemID: item.id)

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.saveMemo(memoInput(body: "メモ", nextCheckupIDAtStart: nextID), now: now)
        }

        // 同じ窓口から見ても、開き直しても、保存前のまま。
        for current in [service, try reopened(store)] {
            #expect(try current.memos().isEmpty)
            #expect(try current.questions().map(\.id) == [asked])
            #expect(try current.questions().first?.isAsked == true)
            #expect(try current.nextCheckup()?.id == nextID)
            #expect(try current.bringItems().first?.isChecked == true)
        }
    }

    @Test func savesAgainAfterAFailure() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.addQuestion(text: "1 回目", now: now)
        }
        #expect(try service.questions().isEmpty)

        store.failures.shouldFail = false
        try service.addQuestion(text: "2 回目", now: now)
        #expect(try service.questions().map(\.text) == ["2 回目"])
    }

    @Test func keepsEverythingAfterReopening() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let asked = try service.addQuestion(text: "聞いた", now: now)
        try service.addQuestion(text: "次に聞く", now: now)
        try service.setAsked(true, questionID: asked)
        try service.setDueDate(today.adding(days: 100))
        let result = try service.saveMemo(memoInput(body: "メモ"), now: now)
        let nextID = try service.setNextCheckup(day: today.adding(days: 14), hour: 9, minute: 0, isReminderOn: true, reminderSlot: ReminderTimeRule.Slot(hour: 22, minute: 30))

        let current = try reopened(store)

        let memo = try #require(try current.memo(id: result.memoID))
        #expect(memo.body == "メモ")
        #expect(memo.sortedItems.map(\.questionText) == ["聞いた"])
        #expect(try current.questions().map(\.text) == ["次に聞く"])
        let next = try #require(try current.nextCheckup())
        #expect(next.id == nextID)
        #expect(next.day == today.adding(days: 14))
        #expect(next.reminderSlot == ReminderTimeRule.Slot(hour: 22, minute: 30))
        #expect(try current.profile()?.dueDate == today.adding(days: 100))
    }

    @Test func preparesTheInitialDataOnlyOnce() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        try service.prepareInitialData(now: now)
        try service.prepareInitialData(now: now)

        #expect(try service.context.fetch(FetchDescriptor<PregnancyProfile>()).count == 1)
        #expect(try service.bringItems().map(\.name) == NoteService.initialBringItemNames)
    }

    // MARK: - 手伝い

    private func memoInput(
        body: String = "",
        excluded: Set<UUID> = [],
        nextCheckupIDAtStart: UUID? = nil
    ) -> MemoInput {
        MemoInput(
            id: UUID(),
            visitDay: today,
            body: body,
            excludedQuestionIDs: excluded,
            nextCheckupIDAtStart: nextCheckupIDAtStart
        )
    }

    private func reopened(_ store: TemporaryStore) throws -> NoteService {
        try store.reopen()
        return store.makeService()
    }
}
