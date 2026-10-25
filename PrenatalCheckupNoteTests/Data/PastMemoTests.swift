import Foundation
import SwiftData
import Testing
@testable import PrenatalCheckupNote

/// 過去の健診後メモを直す（R-18）・削除する（R-19）を、一時的なファイルの保存場所で確かめる。
@MainActor
struct PastMemoTests {
    private let now = TestDates.tokyo(2026, 10, 25, 11, 0)
    private let today = TestDates.day(2026, 10, 25)

    /// 質問 2 件の入った健診後メモを 1 つ作る。
    private func makeMemo(_ service: NoteService) throws -> CheckupMemo {
        let first = try service.addQuestion(text: "腰の痛み", now: now)
        let second = try service.addQuestion(text: "仕事のこと", now: now)
        try service.updateQuestion(id: second, text: "仕事のこと", note: "", answer: "無理のない範囲で")
        try service.setAsked(true, questionID: first)
        try service.setAsked(true, questionID: second)
        try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "様子見でよい", excludedQuestionIDs: [], now: now)
        let result = try service.saveMemo(try service.memoInputFromDraft(), now: now)
        return try #require(try service.memo(id: result.memoID))
    }

    @Test func editsTheDayBodyAndQuestionsAndUndoesIt() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)
        let items = memo.sortedItems
        let later = TestDates.day(2026, 10, 26)

        try service.updateMemo(
            id: memo.id,
            visitDay: later,
            body: " 次は 2 週間後 ",
            items: [
                MemoItemEdit(id: items[0].id, questionText: "腰の痛み（右側）", answer: "湿布でよい"),
                MemoItemEdit(id: items[1].id, questionText: "仕事のこと", answer: ""),
            ],
            now: now
        )

        let edited = try #require(try service.memo(id: memo.id))
        #expect(edited.visitDay == later)
        #expect(edited.body == "次は 2 週間後")
        #expect(edited.sortedItems.map(\.questionText) == ["腰の痛み（右側）", "仕事のこと"])
        #expect(edited.sortedItems.map(\.answer) == ["湿布でよい", ""])

        try service.undo()

        let restored = try #require(try service.memo(id: memo.id))
        #expect(restored.visitDay == today)
        #expect(restored.body == "様子見でよい")
        #expect(restored.sortedItems.map(\.questionText) == ["腰の痛み", "仕事のこと"])
        #expect(restored.sortedItems.map(\.answer) == ["", "無理のない範囲で"])
    }

    @Test func editingDoesNotTakeInQuestionsMarkedAskedNow() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)
        let asked = try service.addQuestion(text: "むくみ", now: now)
        try service.setAsked(true, questionID: asked)

        try service.updateMemo(
            id: memo.id,
            visitDay: today,
            body: "様子見でよい（追記）",
            items: memo.sortedItems.map { MemoItemEdit(id: $0.id, questionText: $0.questionText, answer: $0.answer) },
            now: now
        )

        // いま丸を付けている質問は、過去のメモに入らず、一覧に残る（R-18）。
        #expect(try service.memo(id: memo.id)?.items.count == 2)
        #expect(try service.questions().map(\.text) == ["むくみ"])
    }

    @Test func refusesAnEmptyQuestionText() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)
        let items = memo.sortedItems

        #expect(throws: NoteServiceError.emptyText) {
            try service.updateMemo(
                id: memo.id,
                visitDay: today,
                body: "",
                items: [
                    MemoItemEdit(id: items[0].id, questionText: "  ", answer: ""),
                    MemoItemEdit(id: items[1].id, questionText: "仕事のこと", answer: ""),
                ],
                now: now
            )
        }
        #expect(try service.memo(id: memo.id)?.body == "様子見でよい")
    }

    @Test func deletesAMemoAndBringsItBackWithItsQuestions() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)
        let id = memo.id
        let itemIDs = memo.sortedItems.map(\.id)

        try service.deleteMemo(id: id)
        #expect(try service.memos().isEmpty)
        #expect(try service.context.fetch(FetchDescriptor<MemoItem>()).isEmpty)

        try service.undo()

        let restored = try #require(try service.memo(id: id))
        #expect(restored.body == "様子見でよい")
        #expect(restored.sortedItems.map(\.id) == itemIDs)
        #expect(restored.sortedItems.map(\.answer) == ["", "無理のない範囲で"])
    }

    @Test func deletedMemoCannotComeBackAfterTheUndoBarIsGone() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)

        try service.deleteMemo(id: memo.id)
        service.discardUndo()

        #expect(throws: NoteServiceError.nothingToUndo) {
            try service.undo()
        }
        #expect(try service.memos().isEmpty)
    }

    @Test func failedDeleteKeepsTheMemo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memo = try makeMemo(service)

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.deleteMemo(id: memo.id)
        }

        store.failures.shouldFail = false
        try store.reopen()
        #expect(try store.makeService().memos().count == 1)
    }
}
