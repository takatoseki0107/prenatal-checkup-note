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

        // 帯を出す時間（0.1 秒）より十分長く待つ。
        try await Task.sleep(for: .seconds(1))

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
