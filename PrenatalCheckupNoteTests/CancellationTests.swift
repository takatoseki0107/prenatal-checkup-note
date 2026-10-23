import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 健診のキャンセルを確かめる。要件定義 11章#15・「健診のキャンセル」、14章 X-01〜X-06。
@MainActor
struct CancellationTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeStore(_ scenario: PrototypeScenario = .standard) -> PrototypeStore {
        PrototypeStore(scenario: scenario, now: now)
    }

    // MARK: - 確認に出す内容

    @Test func countsReturningQuestionsAndMemos() {
        let store = makeStore(.cancelNormal)

        let eligibility = store.data.cancellationEligibility(of: store.data.currentAppointmentID)

        #expect(eligibility == .cancellable(CancellationSummary(returningQuestionCount: 4, deletedMemoCount: 1)))
    }

    /// 空でない回答メモだけを数える。回答を取り消した記録と、取り下げ済みの記録のメモも数える（X-03・X-06）。
    @Test func countsEveryNonEmptyMemoThatWillBeDeleted() {
        let store = makeStore()
        store.data.updateCurrentAppointment { appointment in
            // 未確認の記録（短いメモあり）
            appointment.checks[0].answerMemo = "痛む時間帯"
            // 回答を取り消した記録（メモあり）。取り消すと未確認に戻り、メモは残る。
            appointment.checks[1].answerMemo = "書類のこと"
            // 取り下げ済みの記録（メモあり）
            appointment.checks[2].status = .withdrawn
            appointment.checks[2].answerMemo = "検査の前日"
            // 4件目は未確認でメモなし。
        }

        let eligibility = store.data.cancellationEligibility(of: store.data.currentAppointmentID)

        #expect(eligibility == .cancellable(CancellationSummary(returningQuestionCount: 3, deletedMemoCount: 3)))
    }

    /// 保存に失敗して残っている入力も、キャンセルで消えるため数える。
    @Test func countsAnUnsavedMemoAsWell() {
        let store = makeStore()
        let checkID = store.data.currentChecks[0].id
        store.data.unsavedMemos[checkID] = "保存できなかった入力"

        let eligibility = store.data.cancellationEligibility(of: store.data.currentAppointmentID)

        #expect(eligibility == .cancellable(CancellationSummary(returningQuestionCount: 4, deletedMemoCount: 1)))
    }

    // MARK: - キャンセルしない（X-01）

    @Test func doesNotCancelWithRecordedChecks() {
        let store = makeStore(.cancelWithRecords)
        let id = store.data.currentAppointmentID
        let checks = store.data.currentChecks
        let before = store.data

        let eligibility = store.data.cancellationEligibility(of: id)
        let cancelled = store.cancel(id)

        #expect(eligibility == .hasRecordedChecks(answered: [checks[0]], carriedOver: [checks[1]]))
        #expect(!cancelled)
        #expect(store.data == before)
    }

    @Test func doesNotCancelAnAppointmentThatIsNotScheduled() {
        let store = makeStore()
        let previousID = store.data.appointments[0].id
        let before = store.data

        #expect(store.data.cancellationEligibility(of: previousID) == .notScheduled)
        #expect(!store.cancel(previousID))
        #expect(store.data == before)
    }

    // MARK: - キャンセルする

    /// 持ち越しを取り消してからキャンセルすると、質問は未割り当てに戻る（X-02）。
    @Test func cancelsAfterUndoingTheRecords() {
        let store = makeStore(.cancelWithRecords)
        let id = store.data.currentAppointmentID
        let checks = store.data.currentChecks
        store.data.setStatus(.unconfirmed, ofCheck: checks[0].id, in: id)
        store.data.setStatus(.unconfirmed, ofCheck: checks[1].id, in: id)

        #expect(store.cancel(id))

        #expect(store.data.currentAppointment.status == .cancelled)
        #expect(store.data.currentChecks.isEmpty)
        let unassignedIDs = Set(store.data.unassignedQuestions.map(\.id))
        #expect(checks.allSatisfy { unassignedIDs.contains($0.questionID) })
    }

    /// 取り下げ済みの記録も削除され、その質問は取り下げのまま（X-04）。
    @Test func deletesWithdrawnRecordsAndKeepsTheQuestionWithdrawn() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let withdrawnQuestionID = store.data.currentChecks[3].questionID
        let withdrawnAt = now.addingTimeInterval(-60)
        store.data.updateCurrentAppointment { $0.checks[3].status = .withdrawn }
        if let index = store.data.questions.firstIndex(where: { $0.id == withdrawnQuestionID }) {
            store.data.questions[index].withdrawnAt = withdrawnAt
        }

        #expect(store.cancel(id))

        #expect(store.data.currentChecks.isEmpty)
        #expect(store.data.question(id: withdrawnQuestionID)?.withdrawnAt == withdrawnAt)
        #expect(!store.data.unassignedQuestions.contains { $0.id == withdrawnQuestionID })
    }

    /// 診察を始めていて回答のない健診もキャンセルでき、質問は未割り当てに戻る（X-05）。
    @Test func cancelsAnAppointmentWhoseExamHasStarted() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let questionIDs = store.data.currentChecks.map(\.questionID)
        store.data.startExam(of: id, at: now)

        #expect(store.cancel(id))

        let unassignedIDs = Set(store.data.unassignedQuestions.map(\.id))
        #expect(questionIDs.allSatisfy { unassignedIDs.contains($0) })
    }

    /// 削除した記録の未保存のメモと、この健診を行先にしていた持ち越しの行先も消す。
    @Test func clearsUnsavedMemosAndCarryOverLinks() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id
        store.data.unsavedMemos[checkID] = "保存できなかった入力"

        #expect(store.cancel(id))

        #expect(store.data.unsavedMemos.isEmpty)
        let links = store.data.appointments.flatMap(\.checks).compactMap(\.carriedOverToAppointmentID)
        #expect(!links.contains(id))
        // 前回の健診の持ち越しの記録そのものは残る。
        #expect(store.data.appointments[0].checks.count == 3)
    }
}
