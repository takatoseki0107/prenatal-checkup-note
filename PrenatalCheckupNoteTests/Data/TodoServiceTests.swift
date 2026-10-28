import Foundation
import Testing
@testable import PrenatalCheckupNote

/// やること（要件定義 v0.4 の 5.10）の保存と元に戻すを、一時的なファイルの保存場所で確かめる。
@MainActor
struct TodoServiceTests {
    private let now = TestDates.tokyo(2026, 10, 27, 9, 0)
    private let today = TestDates.day(2026, 10, 27)

    private func later(minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    // MARK: - 足す・直す（R-101、R-102）

    @Test func addsATodoTrimmed() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let due = TestDates.day(2026, 11, 9)

        let id = try service.addTodo(title: "  血液検査の受診票に記入する\n", note: " 健診の前の日までに ", dueDay: due, isStarred: true, now: now)

        let todo = try #require(try service.todos().first)
        #expect(todo.id == id)
        #expect(todo.title == "血液検査の受診票に記入する")
        #expect(todo.note == "健診の前の日までに")
        #expect(todo.dueDay == due)
        #expect(todo.isStarred)
        #expect(!todo.isChecked)
        #expect(!todo.isCompleted)
        #expect(todo.originVisitDay == nil)
        #expect(todo.createdAt == now)
    }

    @Test func remembersWhichCheckupTheTodoCameFrom() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let visit = TestDates.day(2026, 10, 12)

        try service.addTodo(title: "母親学級の申し込み", dueDay: nil, originVisitDay: visit, now: now)

        let todo = try #require(try service.todos().first)
        #expect(todo.originVisitDay == visit)
        #expect(todo.dueDay == nil)
    }

    @Test func remembersWhichMemoTheTodoCameFrom() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let memoID = UUID()
        let visit = TestDates.day(2026, 10, 27)

        let id = try service.addTodo(title: "受診票に記入する", dueDay: nil, originVisitDay: visit, originMemoID: memoID, now: now)
        try service.addTodo(title: "自分で足した", dueDay: nil, now: later(minutes: 1))

        let fromMemo = try service.todos().filter { $0.originMemoID == memoID }
        #expect(fromMemo.map(\.id) == [id])
        #expect(fromMemo.first?.originVisitDay == visit)

        // 削除して元に戻しても、どのメモから足したかは残る。
        try service.deleteTodo(id: id)
        try service.undo()
        #expect(try service.todos().first { $0.id == id }?.originMemoID == memoID)

        // 開き直しても残る。
        let current = try reopened(store)
        #expect(try current.todos().first { $0.id == id }?.originMemoID == memoID)
    }

    @Test func keepsTheMemoIDFromTheDraftAfterSavingTheMemo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.prepareInitialData(now: now)
        let draft = try service.startMemoDraft(today: today, now: now)
        try service.updateMemoDraft(visitDay: today, body: "受診票を書いてくる", excludedQuestionIDs: [], now: now)

        // 書いている途中に、書きかけの ID でやることを足す。
        try service.addTodo(title: "受診票に記入する", dueDay: nil, originVisitDay: today, originMemoID: draft.id, now: now)
        let saved = try service.saveMemo(try service.memoInputFromDraft(), now: later(minutes: 5))

        // 書きかけの ID は保存したメモの ID と同じなので、保存したメモから見える。
        #expect(saved.memoID == draft.id)
        #expect(try service.todos().filter { $0.originMemoID == saved.memoID }.map(\.title) == ["受診票に記入する"])
    }

    @Test func refusesABlankTodo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()

        #expect(throws: NoteServiceError.emptyText) {
            try service.addTodo(title: " \u{3000}\n", dueDay: nil, now: now)
        }
        #expect(try service.todos().isEmpty)
    }

    @Test func editsATodo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "産院に電話", dueDay: today, now: now)
        try service.setTodoChecked(true, todoID: id)
        let newDue = TestDates.day(2026, 10, 30)

        try service.updateTodo(id: id, title: " 産院に分娩予約の電話をする ", note: "平日 14 時〜16 時", dueDay: newDue, isStarred: true)

        let todo = try #require(try service.todos().first)
        #expect(todo.title == "産院に分娩予約の電話をする")
        #expect(todo.note == "平日 14 時〜16 時")
        #expect(todo.dueDay == newDue)
        #expect(todo.isStarred)
        // チェックは直しても変わらない。
        #expect(todo.isChecked)

        try service.updateTodo(id: id, title: "産院に分娩予約の電話をする", note: "", dueDay: nil, isStarred: false)
        #expect(try service.todos().first?.dueDay == nil)
        #expect(throws: NoteServiceError.emptyText) {
            try service.updateTodo(id: id, title: "", note: "", dueDay: nil, isStarred: false)
        }
    }

    @Test func keepsTheDueWhenTheNextCheckupMoves() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let checkup = TestDates.day(2026, 11, 9)
        try service.setNextCheckup(day: checkup, hour: 10, minute: 30, isReminderOn: false, reminderSlot: ReminderTimeRule.Slot(hour: 21, minute: 0))
        try service.addTodo(title: "受診票に記入する", dueDay: checkup, now: now)

        try service.setNextCheckup(day: TestDates.day(2026, 11, 16), hour: 10, minute: 30, isReminderOn: false, reminderSlot: ReminderTimeRule.Slot(hour: 21, minute: 0))

        #expect(try service.todos().first?.dueDay == checkup)
    }

    @Test func togglesTheStar() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "星", dueDay: nil, now: now)

        try service.setTodoStarred(true, todoID: id)
        #expect(try service.todos().first?.isStarred == true)
        try service.setTodoStarred(false, todoID: id)
        #expect(try service.todos().first?.isStarred == false)
    }

    // MARK: - 完了は 2 段階（R-104）

    @Test func completesOnlyCheckedTodos() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let first = try service.addTodo(title: "1", dueDay: nil, now: now)
        let second = try service.addTodo(title: "2", dueDay: nil, now: later(minutes: 1))
        let third = try service.addTodo(title: "3", dueDay: nil, now: later(minutes: 2))
        try service.setTodoChecked(true, todoID: first)
        try service.setTodoChecked(true, todoID: third)

        let completedAt = later(minutes: 10)
        let count = try service.completeCheckedTodos(now: completedAt)

        #expect(count == 2)
        let todos = try service.todos()
        #expect(todos.map(\.completedAt) == [completedAt, nil, completedAt])
        #expect(todos.map(\.isChecked) == [false, false, false])
        #expect(service.pendingUndo == .completedTodos(ids: [first, third]))
        #expect(todos.first { $0.id == second }?.isCompleted == false)
    }

    @Test func doesNothingWhenNothingIsChecked() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "消す", dueDay: nil, now: now)
        try service.deleteTodo(id: try service.addTodo(title: "別", dueDay: nil, now: now))

        let count = try service.completeCheckedTodos(now: later(minutes: 5))

        #expect(count == 0)
        // 保存しないので、前の操作の「元に戻す」は残る。
        guard case .deletedTodo? = service.pendingUndo else {
            Issue.record("削除の「元に戻す」が残るはず：\(String(describing: service.pendingUndo))")
            return
        }
        #expect(try service.todos().map(\.id) == [id])
    }

    @Test func bringsCompletedTodosBackChecked() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "母親学級の申し込み", dueDay: today, now: now)
        try service.setTodoChecked(true, todoID: id)
        try service.completeCheckedTodos(now: later(minutes: 5))

        let undone = try service.undo()

        #expect(undone == .completedTodos(ids: [id]))
        let todo = try #require(try service.todos().first)
        #expect(!todo.isCompleted)
        #expect(todo.isChecked)
        #expect(service.pendingUndo == nil)
    }

    @Test func reopensACompletedTodoUnchecked() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "完了を取り消す", dueDay: nil, now: now)
        try service.setTodoChecked(true, todoID: id)
        try service.completeCheckedTodos(now: later(minutes: 5))

        try service.reopenTodo(id: id)

        let todo = try #require(try service.todos().first)
        #expect(!todo.isCompleted)
        #expect(!todo.isChecked)
    }

    // MARK: - 削除（R-105）

    @Test func deletesATodoAndBringsItBackAsItWas() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let visit = TestDates.day(2026, 10, 12)
        let due = TestDates.day(2026, 11, 9)
        try service.addTodo(title: "1", dueDay: nil, now: now)
        let id = try service.addTodo(title: "2", note: "補足", dueDay: due, isStarred: true, originVisitDay: visit, now: later(minutes: 1))
        try service.addTodo(title: "3", dueDay: nil, now: later(minutes: 2))
        try service.setTodoChecked(true, todoID: id)

        try service.deleteTodo(id: id)
        #expect(try service.todos().map(\.title) == ["1", "3"])
        guard case .deletedTodo(let snapshot)? = service.pendingUndo else {
            Issue.record("削除の「元に戻す」があるはず")
            return
        }
        #expect(snapshot.title == "2")

        try service.undo()

        let todos = try service.todos()
        #expect(todos.map(\.title) == ["1", "2", "3"])
        let restored = try #require(todos.first { $0.id == id })
        #expect(restored.note == "補足")
        #expect(restored.dueDay == due)
        #expect(restored.isStarred)
        #expect(restored.isChecked)
        #expect(restored.originVisitDay == visit)
        #expect(restored.createdAt == later(minutes: 1))
    }

    @Test func deletesACompletedTodo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "完了したもの", dueDay: nil, now: now)
        try service.setTodoChecked(true, todoID: id)
        let completedAt = later(minutes: 5)
        try service.completeCheckedTodos(now: completedAt)

        try service.deleteTodo(id: id)
        #expect(try service.todos().isEmpty)

        try service.undo()
        #expect(try service.todos().first?.completedAt == completedAt)
    }

    @Test func refusesAMissingTodo() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "消す", dueDay: nil, now: now)
        try service.deleteTodo(id: id)

        #expect(throws: NoteServiceError.notFound) {
            try service.deleteTodo(id: id)
        }
        #expect(throws: NoteServiceError.notFound) {
            try service.setTodoChecked(true, todoID: id)
        }
    }

    // MARK: - 保存（R-109、S-01、S-07）

    @Test func keepsEverythingWhenSavingFails() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addTodo(title: "残る", dueDay: today, now: now)
        try service.setTodoChecked(true, todoID: id)

        store.failures.shouldFail = true
        #expect(throws: NoteServiceError.saveFailed) {
            try service.addTodo(title: "足せない", dueDay: nil, now: now)
        }
        #expect(throws: NoteServiceError.saveFailed) {
            try service.completeCheckedTodos(now: later(minutes: 5))
        }
        #expect(throws: NoteServiceError.saveFailed) {
            try service.deleteTodo(id: id)
        }

        store.failures.shouldFail = false
        for current in [service, try reopened(store)] {
            let todos = try current.todos()
            #expect(todos.map(\.title) == ["残る"])
            #expect(todos.first?.isChecked == true)
            #expect(todos.first?.isCompleted == false)
        }
    }

    @Test func keepsTodosAfterReopening() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let due = TestDates.day(2026, 11, 9)
        let visit = TestDates.day(2026, 10, 12)
        let id = try service.addTodo(title: "受診票に記入する", note: "前の日までに", dueDay: due, isStarred: true, originVisitDay: visit, now: now)
        try service.setTodoChecked(true, todoID: id)

        let current = try reopened(store)

        let todo = try #require(try current.todos().first)
        #expect(todo.id == id)
        #expect(todo.title == "受診票に記入する")
        #expect(todo.note == "前の日までに")
        #expect(todo.dueDay == due)
        #expect(todo.isStarred)
        #expect(todo.isChecked)
        #expect(todo.originVisitDay == visit)
    }

    @Test func passesTodosToTheListRules() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        try service.addTodo(title: "今日", dueDay: today, now: now)
        try service.addTodo(title: "期限なし", dueDay: nil, now: later(minutes: 1))

        let entries = try service.todos().map(\.listEntry)
        let sections = TodoList.sections(entries, today: today, nextCheckupDay: nil)

        #expect(sections.map(\.title) == ["期限なし", "今日"])
    }

    private func reopened(_ store: TemporaryStore) throws -> NoteService {
        try store.reopen()
        return store.makeService()
    }
}
