import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 元に戻す（R-60〜R-63）と書きかけ（R-70〜R-72）を、一時的なファイルの保存場所で確かめる。
@MainActor
struct UndoAndDraftTests {
    private let now = TestDates.tokyo(2026, 11, 5, 11, 0)
    private let today = TestDates.day(2026, 11, 5)

    // MARK: - 元に戻す

    @Test func bringsBackADeletedQuestionAsItWas() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.addQuestion(text: "1", now: now)
        let id = try service.addQuestion(text: "2", note: "補足", now: now)
        try service.addQuestion(text: "3", now: now)
        try service.updateQuestion(id: id, text: "2", note: "補足", answer: "答え")
        try service.setStarred(true, questionID: id)
        try service.setAsked(true, questionID: id)

        try service.deleteQuestion(id: id)
        let undone = try service.undo()

        guard case .deletedQuestion = undone else {
            Issue.record("質問の削除を戻すはずが、\(undone) を戻した")
            return
        }
        let questions = try service.questions()
        #expect(questions.map(\.text) == ["1", "2", "3"])
        let restored = try #require(questions.first { $0.id == id })
        #expect(restored.note == "補足")
        #expect(restored.answer == "答え")
        #expect(restored.isStarred)
        #expect(restored.isAsked)
        #expect(service.pendingUndo == nil)
    }

    @Test func undoesOnlyTheLastOperation() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let first = try service.addQuestion(text: "1", now: now)
        let second = try service.addQuestion(text: "2", now: now)

        try service.deleteQuestion(id: first)
        try service.deleteQuestion(id: second)
        try service.undo()

        #expect(try service.questions().map(\.id) == [second])
        #expect(throws: NoteServiceError.nothingToUndo) {
            try service.undo()
        }
    }

    @Test func forgetsTheUndoWhenAnotherChangeIsSaved() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addQuestion(text: "消す", now: now)

        try service.deleteQuestion(id: id)
        #expect(service.pendingUndo != nil)
        try service.addQuestion(text: "別の質問", now: now)

        #expect(service.pendingUndo == nil)
        #expect(throws: NoteServiceError.nothingToUndo) {
            try service.undo()
        }
    }

    @Test func keepsTheUndoWhenOnlyReading() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addQuestion(text: "消す", now: now)

        try service.deleteQuestion(id: id)
        _ = try service.questions()
        _ = try service.memos()
        _ = try service.nextCheckup()

        #expect(service.pendingUndo != nil)
    }

    @Test func undoesASavedMemoAndBringsEverythingBack() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let asked = try service.addQuestion(text: "聞いた", now: now)
        try service.setAsked(true, questionID: asked)
        let nextID = try service.setNextCheckup(day: today, hour: 10, minute: 30, isReminderOn: true, reminderSlot: ReminderTimeRule.defaultSlot)
        let item = try #require(try service.bringItems().first)
        try service.setBringItemChecked(true, itemID: item.id)
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "書いた内容", excludedQuestionIDs: [], now: now)

        let result = try service.saveMemo(try service.memoInputFromDraft(), now: now)
        #expect(result.clearedNextCheckup)
        #expect(try service.memoDraft() == nil)

        let undone = try service.undo()

        guard case .savedMemo(let saved) = undone else {
            Issue.record("健診後メモの保存を戻すはずが、\(undone) を戻した")
            return
        }
        #expect(saved.memoID == result.memoID)
        #expect(try service.memos().isEmpty)
        #expect(try service.questions().map(\.id) == [asked])
        #expect(try service.questions().first?.isAsked == true)
        #expect(try service.nextCheckup()?.id == nextID)
        #expect(try service.bringItems().first { $0.id == item.id }?.isChecked == true)
        let draft = try #require(try service.memoDraft())
        #expect(draft.id == result.memoID)
        #expect(draft.body == "書いた内容")
    }

    @Test func savesTheSameMemoAgainAfterUndoing() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "メモ", excludedQuestionIDs: [], now: now)
        try service.saveMemo(try service.memoInputFromDraft(), now: now)
        try service.undo()

        let again = try service.saveMemo(try service.memoInputFromDraft(), now: now)

        #expect(!again.wasAlreadySaved)
        #expect(try service.memos().count == 1)
    }

    @Test func undoesClearingTheNextCheckup() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let nextID = try service.setNextCheckup(day: today, hour: 10, minute: 30, isReminderOn: true, reminderSlot: ReminderTimeRule.Slot(hour: 22, minute: 0))

        try service.clearNextCheckup()
        #expect(try service.nextCheckup() == nil)
        try service.undo()

        let next = try #require(try service.nextCheckup())
        #expect(next.id == nextID)
        #expect(next.reminderSlot == ReminderTimeRule.Slot(hour: 22, minute: 0))
    }

    @Test func keepsTheDataAndTheUndoWhenUndoingFails() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "メモ", excludedQuestionIDs: [], now: now)
        let result = try service.saveMemo(try service.memoInputFromDraft(), now: now)

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.undo()
        }

        #expect(try service.memo(id: result.memoID) != nil)
        #expect(try service.memoDraft() == nil)
        #expect(service.pendingUndo != nil)

        store.failures.shouldFail = false
        try service.undo()
        #expect(try service.memo(id: result.memoID) == nil)
    }

    // MARK: - 書きかけ

    @Test func startsTheMemoDraftOnTheNextCheckupDay() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let checkupDay = today.adding(days: 3)
        let nextID = try service.setNextCheckup(day: checkupDay, hour: 10, minute: 0, isReminderOn: false, reminderSlot: ReminderTimeRule.defaultSlot)

        let draft = try service.startMemoDraft(today: today, now: now)

        #expect(draft.visitDay == checkupDay)
        #expect(draft.nextCheckupIDAtStart == nextID)
    }

    @Test func startsTheMemoDraftTodayWithoutANextCheckup() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        let draft = try service.startMemoDraft(today: today, now: now)

        #expect(draft.visitDay == today)
        #expect(draft.nextCheckupIDAtStart == nil)
    }

    @Test func continuesTheSameMemoDraft() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let first = try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "途中まで", excludedQuestionIDs: [], now: now)

        let second = try service.startMemoDraft(today: today.adding(days: 1), now: now)

        #expect(second.id == first.id)
        #expect(second.body == "途中まで")
    }

    @Test func keepsTheMemoDraftAfterReopening() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let excluded = try service.addQuestion(text: "外した", now: now)
        let draftID = try service.startMemoDraft(today: today, now: now).id
        try service.updateMemoDraft(visitDay: today.adding(days: -1), body: "  途中まで\n", excludedQuestionIDs: [excluded], now: now)

        try store.reopen()
        let current = store.makeService()

        let input = try current.memoInputFromDraft()
        #expect(input.id == draftID)
        #expect(input.visitDay == today.adding(days: -1))
        #expect(input.body == "  途中まで\n")
        #expect(input.excludedQuestionIDs == [excluded])
    }

    @Test func ignoresExcludedQuestionsThatWereDeleted() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let asked = try service.addQuestion(text: "聞いた", now: now)
        let gone = try service.addQuestion(text: "消した", now: now)
        try service.setAsked(true, questionID: asked)
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "", excludedQuestionIDs: [gone], now: now)
        try service.deleteQuestion(id: gone)

        let result = try service.saveMemo(try service.memoInputFromDraft(), now: now)

        let memo = try #require(try service.memo(id: result.memoID))
        #expect(memo.sortedItems.map(\.questionText) == ["聞いた"])
    }

    @Test func discardsTheMemoDraft() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.startMemoDraft(today: today, now: now)

        try service.discardMemoDraft()

        #expect(try service.memoDraft() == nil)
        #expect(throws: NoteServiceError.notFound) {
            try service.memoInputFromDraft()
        }
    }

    @Test func keepsAndClearsTheQuestionDraft() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.updateQuestionDraft(text: "お腹の", note: "", now: now)
        try service.updateQuestionDraft(text: "お腹の張り", note: "夕方", now: now)

        try store.reopen()
        let current = store.makeService()
        let draft = try #require(try current.questionDraft())
        #expect(draft.text == "お腹の張り")
        #expect(draft.note == "夕方")

        try current.addQuestion(text: draft.text, note: draft.note, now: now)
        #expect(try current.questionDraft() == nil)
        #expect(try current.questions().map(\.text) == ["お腹の張り"])
    }
}
