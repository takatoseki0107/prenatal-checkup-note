import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 健診の完了で選ぶ扱いと行先の仮入力を確かめる（要件定義 11章「完了確認の仮入力」）。
struct CompletionDraftTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func startsFromTheSavedStatuses() {
        let data = PrototypeDataFactory.make(.cancelWithRecords, now: now)
        let checks = data.currentChecks

        let draft = CompletionDraft(checks: checks)

        #expect(draft.choice(for: checks[0].id) == .answered)
        #expect(draft.choice(for: checks[1].id) == .carriedOver)
        #expect(draft.choice(for: checks[2].id) == nil)
        #expect(draft.unselectedCount(in: checks) == 2)
    }

    /// 取り下げ済みの記録は選び直せないため、未選択として数えない（14章 C-15）。
    @Test func doesNotCountWithdrawnChecksAsUnselected() {
        var data = PrototypeDataFactory.make(.standard, now: now)
        data.updateCurrentAppointment { $0.checks[0].status = .withdrawn }
        let checks = data.currentChecks

        let draft = CompletionDraft(checks: checks)

        #expect(draft.choice(for: checks[0].id) == nil)
        #expect(draft.unselectedCount(in: checks) == 3)
    }

    @Test func destinationDefaultsToUnassignedAndIsClearedWhenNotCarriedOver() {
        let data = PrototypeDataFactory.make(.standard, now: now)
        let checkID = data.currentChecks[0].id
        let nextID = data.appointments[2].id
        var draft = CompletionDraft(checks: data.currentChecks)

        draft.setChoice(.carriedOver, for: checkID)
        #expect(draft.destination(for: checkID) == nil)

        draft.setDestination(nextID, for: [checkID])
        #expect(draft.destination(for: checkID) == nextID)

        draft.setChoice(.answered, for: checkID)
        #expect(draft.destination(for: checkID) == nil)
    }

    /// 仮入力を変えても、保存済みのデータは変わらない（14章 P-01 の前提）。
    @Test func editingTheDraftDoesNotTouchTheData() {
        let data = PrototypeDataFactory.make(.standard, now: now)
        let before = data
        var draft = CompletionDraft(checks: data.currentChecks)

        for check in data.currentChecks {
            draft.setChoice(.withdrawn, for: check.id)
        }

        #expect(data == before)
    }
}

/// 持ち越し・割り当ての行先の候補の規則を確かめる（要件定義 11章、14章 C-01・C-04・C-08・C-09・C-14）。
struct DestinationRulesTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeAppointment(
        daysFromNow days: Double,
        status: AppointmentStatus = .scheduled,
        examStarted: Bool = false,
        checks: [PrototypeCheck] = []
    ) -> PrototypeAppointment {
        let date = now.addingTimeInterval(days * 24 * 60 * 60)
        return PrototypeAppointment(
            id: UUID(),
            scheduledAt: date,
            clinicName: "テスト",
            status: status,
            examStartedAt: examStarted ? date : nil,
            memo: "",
            checks: checks
        )
    }

    private func makeCheck(questionID: UUID, status: CheckStatus) -> PrototypeCheck {
        PrototypeCheck(
            id: UUID(),
            questionID: questionID,
            questionText: "質問",
            status: status,
            answerMemo: "",
            carriedOverToAppointmentID: nil
        )
    }

    @Test func listsOnlyOtherScheduledAppointments() {
        let data = PrototypeDataFactory.make(.standard, now: now)
        let questionID = data.currentChecks[0].questionID

        let options = DestinationRules.options(for: questionID, completing: data.currentAppointmentID, in: data, now: now)

        // 今回の健診と完了した前回の健診は出さず、次回の健診だけが候補になる。
        #expect(options.selectable.map(\.id) == [data.appointments[2].id])
        #expect(options.unavailable.isEmpty)
    }

    @Test func showsWhyAnAppointmentCannotBeChosen() {
        var data = PrototypeDataFactory.make(.standard, now: now)
        let questionID = data.currentChecks[0].questionID
        let past = makeAppointment(daysFromNow: -1)
        let pastButStarted = makeAppointment(daysFromNow: -1, examStarted: true)
        let alreadyHasIt = makeAppointment(daysFromNow: 10, checks: [makeCheck(questionID: questionID, status: .unconfirmed)])
        let onlyWithdrawn = makeAppointment(daysFromNow: 20, checks: [makeCheck(questionID: questionID, status: .withdrawn)])
        let cancelled = makeAppointment(daysFromNow: 30, status: .cancelled)
        data.appointments += [past, pastButStarted, alreadyHasIt, onlyWithdrawn, cancelled]

        let options = DestinationRules.options(for: questionID, completing: data.currentAppointmentID, in: data, now: now)
        let selectableIDs = Set(options.selectable.map(\.id))
        let reasons = Dictionary(uniqueKeysWithValues: options.unavailable.map { ($0.appointment.id, $0.reason) })

        // 日時を過ぎて診察を始めていない健診は、理由を付けて選べない（C-08）。
        #expect(reasons[past.id] == .pastAndNotStarted)
        // 日時を過ぎても、診察を始めた健診は選べる（C-09）。
        #expect(selectableIDs.contains(pastButStarted.id))
        // 同じ質問の記録がある健診は選べない。取り下げ済みの記録だけなら選べる（C-04）。
        #expect(reasons[alreadyHasIt.id] == .alreadyHasQuestion)
        #expect(selectableIDs.contains(onlyWithdrawn.id))
        // キャンセルした健診は、どちらにも出さない。
        #expect(!selectableIDs.contains(cancelled.id))
        #expect(reasons[cancelled.id] == nil)
    }

    /// 予定の健診がなければ、候補は何もない（未割り当てだけになる。C-14）。
    @Test func hasNoOptionsWithoutOtherScheduledAppointments() {
        let data = PrototypeDataFactory.make(.noDestinations, now: now)
        let questionID = data.currentChecks[0].questionID

        let options = DestinationRules.options(for: questionID, completing: data.currentAppointmentID, in: data, now: now)

        #expect(options.selectable.isEmpty)
        #expect(options.unavailable.isEmpty)
    }
}

/// 回答メモの編集画面での保存の失敗を確かめる（14章 M-05・M-11 の前提）。
@MainActor
struct AnswerMemoEditorSaveTests {
    @Test func editorFailureDoesNotTurnTheInputIntoAnUnsavedMemo() {
        let store = PrototypeStore(scenario: .memoSaveFails)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[0].id

        let saved = store.saveMemo("編集画面の入力", checkID: checkID, in: id, keepsUnsavedOnFailure: false)

        #expect(!saved)
        #expect(store.data.unsavedMemos[checkID] == nil)
        #expect(store.data.currentChecks[0].answerMemo.isEmpty)
    }

    /// 引き継いだ未保存のメモは、編集画面の保存が失敗しても上書きされない（M-11）。
    @Test func editorFailureKeepsTheInheritedUnsavedMemo() {
        let store = PrototypeStore(scenario: .unsavedMemoAtConfirm)
        store.failures.memoSave = true
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[3].id
        let inherited = store.data.unsavedMemos[checkID]

        store.saveMemo("書き足した入力", checkID: checkID, in: id, keepsUnsavedOnFailure: false)

        #expect(inherited != nil)
        #expect(store.data.unsavedMemos[checkID] == inherited)
    }
}
