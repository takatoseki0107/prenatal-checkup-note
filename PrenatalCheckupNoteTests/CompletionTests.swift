import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 健診の完了（最終確定）で、仮入力がまとめて反映されるか、失敗したら何も変わらないかを確かめる。
/// 要件定義 11章#9、14章 C-10・C-12・C-15・E-02・E-03・M-10・P-02。
@MainActor
struct CompletionTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeStore(_ scenario: PrototypeScenario = .standard) -> PrototypeStore {
        PrototypeStore(scenario: scenario, now: now)
    }

    /// 次回の健診（標準データの3件目）。
    private func nextAppointmentID(_ store: PrototypeStore) -> UUID {
        store.data.appointments[2].id
    }

    // MARK: - 完了できる

    @Test func appliesEveryChoiceAtOnce() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let nextID = nextAppointmentID(store)
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        draft.setChoice(.answered, for: checks[0].id)
        draft.setChoice(.carriedOver, for: checks[1].id)
        draft.setDestination(nextID, for: [checks[1].id])
        draft.setChoice(.carriedOver, for: checks[2].id)
        draft.setChoice(.withdrawn, for: checks[3].id)

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .completed)
        let completed = store.data.currentAppointment
        #expect(completed.status == .completed)
        #expect(completed.checks.map(\.status) == [.answered, .carriedOver, .carriedOver, .withdrawn])
        // 持ち越しの行先を記録する。未割り当てなら空のまま（#9b・#9c）。
        #expect(completed.checks[1].carriedOverToAppointmentID == nextID)
        #expect(completed.checks[2].carriedOverToAppointmentID == nil)
        // 行先の健診には、未確認の記録が1件だけ作られる。
        let next = store.data.appointment(id: nextID)
        #expect(next?.checks.map(\.questionID) == [checks[1].questionID])
        #expect(next?.checks.first?.status == .unconfirmed)
        // 取り下げを選んだ質問は、取り下げ日時を記録する（#9d）。
        #expect(store.data.question(id: checks[3].questionID)?.withdrawnAt == now)
        // 未割り当てを選んだ持ち越しの質問は、未割り当ての一覧に出る。
        #expect(store.data.unassignedQuestions.contains { $0.id == checks[2].questionID })
    }

    /// 診察中に回答済みにした質問を、完了の画面で持ち越しに変える（C-10）。回答メモは残る。
    @Test func changesARecordedAnswerToACarryOverAndKeepsTheMemo() {
        let store = makeStore(.cancelWithRecords)
        let id = store.data.currentAppointmentID
        let nextID = nextAppointmentID(store)
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        draft.setChoice(.carriedOver, for: checks[0].id)
        draft.setDestination(nextID, for: [checks[0].id])
        draft.setChoice(.answered, for: checks[2].id)
        draft.setChoice(.answered, for: checks[3].id)

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .completed)
        let check = store.data.currentChecks[0]
        #expect(check.status == .carriedOver)
        #expect(check.answerMemo == "次回の健診でもう一度伝える")
        #expect(store.data.appointment(id: nextID)?.checks.count == 1)
    }

    /// 取り下げ済みの記録は変えず、扱いを選ばなくても完了できる（C-15、E-03）。
    @Test func leavesAlreadyWithdrawnRecordsAsTheyAre() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        store.data.updateCurrentAppointment { appointment in
            for index in appointment.checks.indices {
                appointment.checks[index].status = .withdrawn
            }
        }
        let before = store.data.currentChecks

        let outcome = store.complete(id, with: CompletionDraft(checks: before), now: now)

        #expect(outcome == .completed)
        #expect(store.data.currentAppointment.status == .completed)
        #expect(store.data.currentChecks == before)
    }

    /// 質問のない健診も完了でき、記録は作られない（E-02）。
    @Test func completesAnAppointmentWithoutQuestions() {
        let store = makeStore(.noQuestions)
        let id = store.data.currentAppointmentID

        let outcome = store.complete(id, with: CompletionDraft(checks: []), now: now)

        #expect(outcome == .completed)
        #expect(store.data.currentAppointment.status == .completed)
        #expect(store.data.currentChecks.isEmpty)
    }

    // MARK: - 完了できない・失敗する

    /// 完了の保存に失敗したら、何も変わらない（P-02・C-12）。
    @Test func saveFailureChangesNothing() {
        let store = makeStore(.completionSaveFails)
        let id = store.data.currentAppointmentID
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        for check in checks {
            draft.setChoice(.carriedOver, for: check.id)
        }
        draft.setDestination(nextAppointmentID(store), for: checks.map(\.id))
        let before = store.data

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .saveFailed)
        #expect(store.data == before)
    }

    /// 失敗の設定を外して、同じ仮入力でもう一度試すと完了できる（P-02「再試行できる」）。
    @Test func retryWithTheSameDraftSucceedsAfterTheFailureIsTurnedOff() {
        let store = makeStore(.completionSaveFails)
        let id = store.data.currentAppointmentID
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        for check in checks {
            draft.setChoice(.answered, for: check.id)
        }
        #expect(store.complete(id, with: draft, now: now) == .saveFailed)

        store.failures.completionSave = false

        #expect(store.complete(id, with: draft, now: now) == .completed)
        #expect(store.data.currentChecks.allSatisfy { $0.status == .answered })
    }

    @Test func rejectsWhenAChoiceIsMissing() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        draft.setChoice(.answered, for: checks[0].id)
        let before = store.data

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .rejected([.unselected(count: 3)]))
        #expect(store.data == before)
    }

    /// 選んだ後に、行先の健診に同じ質問が入ったら、何も変えずに止める。
    @Test func rejectsADestinationThatIsNoLongerAvailable() {
        let store = makeStore()
        let id = store.data.currentAppointmentID
        let nextID = nextAppointmentID(store)
        let checks = store.data.currentChecks
        var draft = CompletionDraft(checks: checks)
        for check in checks {
            draft.setChoice(.answered, for: check.id)
        }
        draft.setChoice(.carriedOver, for: checks[0].id)
        draft.setDestination(nextID, for: [checks[0].id])
        store.data.assign(questionIDs: [checks[0].questionID], to: nextID)
        let before = store.data

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .rejected([.destinationUnavailable(checkID: checks[0].id)]))
        #expect(store.data == before)
    }

    @Test func rejectsAnAppointmentThatIsAlreadyCompleted() {
        let store = makeStore()
        let previousID = store.data.appointments[0].id
        let before = store.data

        let outcome = store.complete(previousID, with: CompletionDraft(checks: []), now: now)

        #expect(outcome == .rejected([.appointmentNotScheduled]))
        #expect(store.data == before)
    }

    // MARK: - 未保存のメモ（M-10）

    @Test func stopsWhileAnUnsavedMemoRemains() {
        let store = makeStore(.unsavedMemoAtConfirm)
        let id = store.data.currentAppointmentID
        let draft = CompletionDraft(checks: store.data.currentChecks)
        let before = store.data

        let outcome = store.complete(id, with: draft, now: now)

        #expect(outcome == .hasUnsavedMemos)
        #expect(store.data == before)
        #expect(store.data.unsavedMemoCheckIDs(in: id) == [store.data.currentChecks[3].id])
    }

    /// 破棄を選ぶと保存済みのメモに戻り、完了できる。
    @Test func discardingTheUnsavedMemoRestoresTheSavedMemoAndAllowsCompletion() {
        let store = makeStore(.unsavedMemoAtConfirm)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[3].id
        let savedMemo = store.data.currentChecks[3].answerMemo
        let draft = CompletionDraft(checks: store.data.currentChecks)

        store.discardUnsavedMemo(checkID: checkID)

        #expect(store.data.unsavedMemos[checkID] == nil)
        #expect(store.data.currentChecks[3].answerMemo == savedMemo)
        #expect(store.complete(id, with: draft, now: now) == .completed)
    }

    /// 再試行して保存できれば、その入力が保存され、完了できる。
    @Test func retryingTheUnsavedMemoSavesItAndAllowsCompletion() {
        let store = makeStore(.unsavedMemoAtConfirm)
        let id = store.data.currentAppointmentID
        let checkID = store.data.currentChecks[3].id
        let unsavedText = store.data.unsavedMemos[checkID]
        let draft = CompletionDraft(checks: store.data.currentChecks)

        #expect(store.retryUnsavedMemo(checkID: checkID, in: id))

        #expect(store.data.currentChecks[3].answerMemo == unsavedText)
        #expect(store.complete(id, with: draft, now: now) == .completed)
    }
}

/// 内容の確認に並べる一覧を確かめる。
struct CompletionSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func listsChoicesInOrderWithTheDestination() {
        var data = PrototypeDataFactory.make(.standard, now: now)
        data.updateCurrentAppointment { $0.checks[3].status = .withdrawn }
        let checks = data.currentChecks
        let nextID = data.appointments[2].id
        var draft = CompletionDraft(checks: checks)
        draft.setChoice(.carriedOver, for: checks[0].id)
        draft.setDestination(nextID, for: [checks[0].id])
        draft.setChoice(.answered, for: checks[2].id)

        let items = draft.summaryItems(for: checks)

        // 扱いを選んでいない2件目は含めない。取り下げ済みの4件目は、取り下げとして含める。
        #expect(items.map(\.number) == [1, 3, 4])
        #expect(items.map(\.choice) == [.carriedOver, .answered, .withdrawn])
        #expect(items[0].destinationID == nextID)
        #expect(items[1].destinationID == nil)
        #expect(items.map(\.wasAlreadyWithdrawn) == [false, false, true])
    }
}

/// 健診を完了した後に、健診詳細まで戻るかを確かめる。
@MainActor
struct PrototypeNavigatorTests {
    @Test func popsBackToTheAppointment() {
        let id = UUID()
        let navigator = PrototypeNavigator()
        navigator.path = [.appointment(id), .beforeExam(id), .duringExam(id), .afterExam(id)]

        navigator.popToAppointment(id)

        #expect(navigator.path == [.appointment(id)])
    }

    @Test func opensTheAppointmentWhenItIsNotInThePath() {
        let id = UUID()
        let navigator = PrototypeNavigator()
        navigator.path = [.afterExam(id)]

        navigator.popToAppointment(id)

        #expect(navigator.path == [.appointment(id)])
    }
}
