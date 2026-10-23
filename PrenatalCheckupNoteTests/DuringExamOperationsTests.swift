import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 診察中の画面の操作（回答済み・持ち越しの記録と取り消し、短いメモの保存）で、試作用データが正しく変わるかを確かめる。
struct DuringExamOperationsTests {
    private func makeStandard() -> PrototypeData {
        PrototypeDataFactory.make(.standard, now: Date(timeIntervalSince1970: 1_793_000_000))
    }

    @Test func recordsAnsweredAndCarriedOver() {
        var data = makeStandard()
        let id = data.currentAppointmentID
        let first = data.currentChecks[0].id
        let second = data.currentChecks[1].id

        data.setStatus(.answered, ofCheck: first, in: id)
        data.setStatus(.carriedOver, ofCheck: second, in: id)

        #expect(data.currentChecks.map(\.status) == [.answered, .carriedOver, .unconfirmed, .unconfirmed])
    }

    /// 取り消しても回答メモは残る（11章#6）。
    @Test func undoingKeepsTheMemo() {
        var data = makeStandard()
        let id = data.currentAppointmentID
        let checkID = data.currentChecks[0].id
        data.saveMemo("メモ", ofCheck: checkID, in: id)
        data.setStatus(.answered, ofCheck: checkID, in: id)

        data.setStatus(.unconfirmed, ofCheck: checkID, in: id)

        #expect(data.currentChecks[0].status == .unconfirmed)
        #expect(data.currentChecks[0].answerMemo == "メモ")
    }

    @Test func savingAMemoClearsItsUnsavedInput() {
        var data = makeStandard()
        let id = data.currentAppointmentID
        let checkID = data.currentChecks[0].id
        data.unsavedMemos[checkID] = "古い入力"

        data.saveMemo("新しい入力", ofCheck: checkID, in: id)

        #expect(data.currentChecks[0].answerMemo == "新しい入力")
        #expect(data.unsavedMemos[checkID] == nil)
    }
}

/// 短いメモの保存の失敗と再試行を確かめる（14章 M-06・M-09 の画面側の前提）。
@MainActor
struct MemoSaveTests {
    @Test func failedSaveKeepsTheInputAsUnsaved() {
        let store = PrototypeStore(scenario: .memoSaveFails)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id

        let saved = store.saveMemo("診察中のメモ", checkID: checkID, in: id)

        #expect(!saved)
        #expect(store.data.unsavedMemos[checkID] == "診察中のメモ")
        #expect(store.data.currentChecks[0].answerMemo.isEmpty)
    }

    /// メモの保存に失敗しても、回答済みの記録は取り消さない（11章「診察中の短いメモ」）。
    @Test func failedSaveDoesNotUndoTheStatus() {
        let store = PrototypeStore(scenario: .memoSaveFails)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id
        store.data.setStatus(.answered, ofCheck: checkID, in: id)

        store.saveMemo("診察中のメモ", checkID: checkID, in: id)

        #expect(store.data.currentChecks[0].status == .answered)
    }

    @Test func retrySavesTheLatestInputOnceSavingWorks() {
        let store = PrototypeStore(scenario: .memoSaveFails)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id
        store.saveMemo("1回目", checkID: checkID, in: id)
        store.saveMemo("2回目", checkID: checkID, in: id)
        #expect(!store.retryUnsavedMemo(checkID: checkID, in: id))

        store.failures.memoSave = false
        let saved = store.retryUnsavedMemo(checkID: checkID, in: id)

        #expect(saved)
        #expect(store.data.currentChecks[0].answerMemo == "2回目")
        #expect(store.data.unsavedMemos[checkID] == nil)
    }

    /// 新しい内容の保存に成功した後は、古い入力の再試行を実行しない（14章 M-09）。
    @Test func retryDoesNothingAfterANewerSaveSucceeded() {
        let store = PrototypeStore(scenario: .memoSaveFails)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id
        store.saveMemo("古い入力", checkID: checkID, in: id)

        store.failures.memoSave = false
        store.saveMemo("新しい入力", checkID: checkID, in: id)
        let retried = store.retryUnsavedMemo(checkID: checkID, in: id)

        #expect(!retried)
        #expect(store.data.currentChecks[0].answerMemo == "新しい入力")
    }
}
