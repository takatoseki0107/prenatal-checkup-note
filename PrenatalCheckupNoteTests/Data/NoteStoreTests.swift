import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 画面と窓口をつなぐ `NoteStore` と、元に戻すの帯を時間で消す決まり（R-60）を確かめる。
@MainActor
struct NoteStoreTests {
    private let now = TestDates.tokyo(2026, 11, 5, 11, 0)

    @Test func discardingTheUndoMeansTheDeletedQuestionCannotComeBack() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let id = try service.addQuestion(text: "腰の痛み", now: now)
        try service.deleteQuestion(id: id)

        service.discardUndo()

        #expect(service.pendingUndo == nil)
        #expect(throws: NoteServiceError.nothingToUndo) {
            try service.undo()
        }
        #expect(try service.questions().isEmpty)
    }

    @Test func undoBarDisappearsAfterTheDisplayTime() async throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let noteStore = NoteStore(container: store.container, service: service, undoDisplayDuration: .milliseconds(100))
        noteStore.perform { try $0.addQuestion(text: "腰の痛み", now: now) }
        let id = try #require(noteStore.questions.first?.id)

        noteStore.perform { try $0.deleteQuestion(id: id) }
        #expect(noteStore.pendingUndo != nil)

        // 帯を出す時間（0.1 秒）が過ぎて、帯が消えるまで待つ。
        // ほかのテストと同時に動くと画面のスレッド（メインアクター）が混み、消す処理が始まるのが遅れることがある。
        // そのため、決まった時間だけ待つのではなく、消えるまで 0.05 秒ごとに確かめる（最大 10 秒。ToDo 1 で、1 秒では足りなかった）。
        let deadline = ContinuousClock.now + .seconds(10)
        while noteStore.pendingUndo != nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(noteStore.pendingUndo == nil)
        #expect(service.pendingUndo == nil)
    }

    @Test func undoBarStaysWhileItIsShown() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let noteStore = NoteStore(container: store.container, service: service, undoDisplayDuration: .seconds(60))
        noteStore.perform { try $0.addQuestion(text: "腰の痛み", now: now) }
        let id = try #require(noteStore.questions.first?.id)
        noteStore.perform { try $0.deleteQuestion(id: id) }

        // 帯が出ている間は戻せる。
        noteStore.perform { try $0.undo() }

        #expect(noteStore.questions.map(\.text) == ["腰の痛み"])
        #expect(noteStore.errorMessage == nil)
    }

    @Test func showsTheMessageForTheSceneWhenASaveFails() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let noteStore = NoteStore(container: store.container, service: service, undoDisplayDuration: .seconds(60))
        store.failures.shouldFail = true

        // 書き始めるだけで、まだ何も入力していない場面では「入力した内容はそのままです」と出さない。
        let started = noteStore.perform(saveFailureMessage: "健診後メモを書き始められませんでした。もう一度試してください。") {
            try $0.startMemoDraft(today: TestDates.day(2026, 11, 5), now: now)
        }
        #expect(started == nil)
        #expect(noteStore.errorMessage == "健診後メモを書き始められませんでした。もう一度試してください。")

        // 文を渡さなければ、いつもの文になる。保存の失敗ではないエラーは、そのエラーの文のまま。
        noteStore.errorMessage = nil
        noteStore.perform { try $0.addQuestion(text: "むくみ", now: now) }
        #expect(noteStore.errorMessage == NoteServiceError.saveFailed.message)
        noteStore.errorMessage = nil
        noteStore.perform(saveFailureMessage: "使われない文") { try $0.addQuestion(text: "  ", now: now) }
        #expect(noteStore.errorMessage == NoteServiceError.emptyText.message)
    }

    @Test func failedSaveKeepsTheUndoBar() throws {
        let store = try TemporaryStore()
        let service = store.makeService()
        let noteStore = NoteStore(container: store.container, service: service, undoDisplayDuration: .seconds(60))
        noteStore.perform { try $0.addQuestion(text: "腰の痛み", now: now) }
        noteStore.perform { try $0.addQuestion(text: "仕事のこと", now: now) }
        let id = try #require(noteStore.questions.first?.id)
        noteStore.perform { try $0.deleteQuestion(id: id) }
        let undoBefore = noteStore.pendingUndo

        // 保存に失敗した操作では、前の「元に戻す」は消えない（R-63 と同じ考え方）。
        store.failures.shouldFail = true
        noteStore.perform { try $0.addQuestion(text: "むくみ", now: now) }

        #expect(noteStore.errorMessage != nil)
        #expect(noteStore.pendingUndo == undoBefore)
        #expect(noteStore.questions.map(\.text) == ["仕事のこと"])
    }
}
