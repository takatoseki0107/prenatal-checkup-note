import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 段階1の試作用データが、要件定義 17章「試作用データ」のとおりに作られるかを確かめる。
struct PrototypeDataFactoryTests {
    /// 日付の計算に使う暦。テストの結果が実行する環境の設定に左右されないよう、日本時間に固定する。
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// テストで使う現在日時：2026年11月5日 9時00分（日本時間）。
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!
    }

    private func make(_ scenario: PrototypeScenario, now: Date? = nil) -> PrototypeData {
        PrototypeDataFactory.make(scenario, now: now ?? self.now, calendar: calendar)
    }

    /// 日時を [年, 月, 日, 時, 分] の数に分ける。
    private func dateParts(of date: Date) -> [Int] {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [components.year, components.month, components.day, components.hour, components.minute].map { $0 ?? -1 }
    }

    // MARK: - 標準データ

    @Test func standardHasThreeAppointmentsDatedRelativeToToday() {
        let data = make(.standard)

        #expect(data.appointments.map(\.status) == [.completed, .scheduled, .scheduled])
        #expect(data.appointments.map { dateParts(of: $0.scheduledAt) } == [
            [2026, 10, 8, 10, 30],
            [2026, 11, 5, 10, 30],
            [2026, 12, 3, 10, 30],
        ])
        #expect(data.currentAppointment.id == data.appointments[1].id)
    }

    @Test func datesFollowTheLaunchDate() {
        let later = calendar.date(byAdding: .day, value: 40, to: now)!
        let data = make(.standard, now: later)

        #expect(dateParts(of: data.currentAppointment.scheduledAt) == [2026, 12, 15, 10, 30])
    }

    @Test func standardCurrentAppointmentHasFourUnconfirmedQuestions() {
        let current = make(.standard).currentAppointment

        #expect(current.status == .scheduled)
        #expect(current.examStartedAt == nil)
        #expect(current.checks.map(\.questionText) == PrototypeDataFactory.currentQuestionTexts)
        #expect(current.checks.allSatisfy { $0.status == .unconfirmed && $0.answerMemo.isEmpty })
    }

    @Test func standardPreviousAppointmentHasAnsweredAndCarriedOverChecks() throws {
        let data = make(.standard)
        let previous = data.appointments[0]

        let answered = previous.checks.filter { $0.status == .answered }
        #expect(answered.count == 2)
        #expect(answered.filter { !$0.answerMemo.isEmpty }.count == 1)

        let carriedOver = previous.checks.filter { $0.status == .carriedOver }
        #expect(carriedOver.count == 1)
        let carried = try #require(carriedOver.first)
        #expect(carried.carriedOverToAppointmentID == data.currentAppointmentID)
        // 持ち越した質問は、今回の4件のうちの1件。
        #expect(data.currentChecks.contains { $0.questionID == carried.questionID })
    }

    @Test func standardHasTwoUnassignedAndOneWithdrawnQuestion() {
        let data = make(.standard)

        #expect(data.unassignedQuestions.map(\.text) == PrototypeDataFactory.unassignedQuestionTexts)
        #expect(data.withdrawnQuestions.map(\.text) == [PrototypeDataFactory.withdrawnQuestionText])
        #expect(data.appointments[2].checks.isEmpty)
        #expect(data.unsavedMemos.isEmpty)
    }

    // MARK: - すべての状態に共通する前提

    @Test(arguments: PrototypeScenario.allCases)
    func everyScenarioKeepsTheDataConsistent(_ scenario: PrototypeScenario) {
        let data = make(scenario)
        let current = data.currentAppointment
        let questionIDs = Set(data.questions.map(\.id))

        // 今回の健診は予定のまま。
        #expect(current.status == .scheduled)
        // 質問のIDに重複がない。
        #expect(questionIDs.count == data.questions.count)
        for appointment in data.appointments {
            // 同じ健診に、同じ質問の記録は1件だけ。
            #expect(Set(appointment.checks.map(\.questionID)).count == appointment.checks.count)
            for check in appointment.checks {
                // 記録が指す質問は必ずある。
                #expect(questionIDs.contains(check.questionID))
            }
        }
        // 未保存のメモは、今回の健診の記録にだけ付く。
        #expect(Set(data.unsavedMemos.keys).isSubset(of: Set(current.checks.map(\.id))))
    }

    // MARK: - 状態ごとの差分

    @Test func noQuestionsRemovesCurrentChecks() {
        let data = make(.noQuestions)

        #expect(data.currentChecks.isEmpty)
        // 前回から持ち越した質問は、行先がなくなり未割り当てに戻る。
        #expect(data.unassignedQuestions.count == 3)
        #expect(!data.appointments.flatMap(\.checks).contains { $0.carriedOverToAppointmentID == data.currentAppointmentID })
    }

    @Test func noUnassignedQuestionsRemovesOnlyUnassignedQuestions() {
        let data = make(.noUnassignedQuestions)

        #expect(data.unassignedQuestions.isEmpty)
        #expect(data.currentChecks.count == 4)
        #expect(data.withdrawnQuestions.count == 1)
    }

    @Test func noDestinationsRemovesTheNextAppointment() {
        let data = make(.noDestinations)
        let current = data.currentAppointment

        #expect(data.appointments.count == 2)
        #expect(!data.appointments.contains { $0.status == .scheduled && $0.scheduledAt > current.scheduledAt })
    }

    @Test func cancelNormalHasOnlyUnconfirmedChecksWithOneMemo() {
        let checks = make(.cancelNormal).currentChecks

        #expect(checks.allSatisfy { $0.status == .unconfirmed })
        #expect(checks.filter { !$0.answerMemo.isEmpty }.count == 1)
    }

    @Test func cancelWithRecordsHasAnsweredAndCarriedOverChecks() {
        let statuses = make(.cancelWithRecords).currentChecks.map(\.status)

        #expect(statuses.contains(.answered))
        #expect(statuses.contains(.carriedOver))
    }

    @Test func manyQuestionsHasTwelveUnconfirmedChecks() {
        let checks = make(.manyQuestions).currentChecks

        #expect(checks.count == 12)
        #expect(checks.allSatisfy { $0.status == .unconfirmed })
    }

    @Test func unsavedMemoAtConfirmStartsTheExamAndKeepsOneUnsavedMemo() {
        let data = make(.unsavedMemoAtConfirm)

        #expect(data.currentAppointment.examStartedAt != nil)
        #expect(!data.currentChecks.contains { $0.status == .unconfirmed })
        #expect(data.unsavedMemos.count == 1)
    }

    @Test func failuresAreOnlyEnabledByTheirScenarios() {
        #expect(PrototypeScenario.completionSaveFails.initialFailures == PrototypeFailures(completionSave: true, memoSave: false))
        #expect(PrototypeScenario.memoSaveFails.initialFailures == PrototypeFailures(completionSave: false, memoSave: true))
        #expect(PrototypeScenario.standard.initialFailures == PrototypeFailures())
    }
}

/// 状態を切り替えたときの、データの置き場所の動きを確かめる。
@MainActor
struct PrototypeStoreTests {
    @Test func applyRebuildsDataAndFailures() {
        let store = PrototypeStore(scenario: .completionSaveFails)
        #expect(store.failures.completionSave)

        store.apply(.manyQuestions)

        #expect(store.scenario == .manyQuestions)
        #expect(store.data.currentChecks.count == 12)
        #expect(store.failures == PrototypeFailures())
    }

    @Test func startPathOpensTheFirstScreenOfTheScenario() {
        let store = PrototypeStore(scenario: .unsavedMemoAtConfirm)
        let currentID = store.data.currentAppointmentID
        #expect(store.startPath == [.appointment(currentID), .afterExam(currentID)])

        store.apply(.sharePreview)
        let newCurrentID = store.data.currentAppointmentID
        #expect(store.startPath == [.appointment(newCurrentID), .sharePreview(newCurrentID)])

        store.apply(.standard)
        #expect(store.startPath == [.appointment(store.data.currentAppointmentID)])
    }
}
