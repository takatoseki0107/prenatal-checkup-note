import Foundation
import Testing
@testable import PrenatalCheckupNote

/// 診察前の画面の操作（並べ替え・追加・割り当て・診察の開始）で、試作用データが正しく変わるかを確かめる。
struct PrototypeOperationsTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeStandard() -> PrototypeData {
        PrototypeDataFactory.make(.standard, now: now)
    }

    private func currentTexts(_ data: PrototypeData) -> [String] {
        data.currentAppointment.activeChecks.map(\.questionText)
    }

    // MARK: - 並べ替え

    @Test func movesTheFirstQuestionToTheEnd() {
        var data = makeStandard()
        let texts = PrototypeDataFactory.currentQuestionTexts

        data.moveActiveChecks(in: data.currentAppointmentID, fromOffsets: IndexSet(integer: 0), toOffset: 4)

        #expect(currentTexts(data) == [texts[1], texts[2], texts[3], texts[0]])
    }

    @Test func movesTheLastQuestionToTheTop() {
        var data = makeStandard()
        let texts = PrototypeDataFactory.currentQuestionTexts

        data.moveActiveChecks(in: data.currentAppointmentID, fromOffsets: IndexSet(integer: 3), toOffset: 0)

        #expect(currentTexts(data) == [texts[3], texts[0], texts[1], texts[2]])
    }

    /// VoiceOver の「上へ移動」「下へ移動」と同じ動かし方。
    @Test func movesOneStepUpAndDown() {
        var data = makeStandard()
        let texts = PrototypeDataFactory.currentQuestionTexts
        let id = data.currentAppointmentID

        data.moveActiveChecks(in: id, fromOffsets: IndexSet(integer: 2), toOffset: 1)
        #expect(currentTexts(data) == [texts[0], texts[2], texts[1], texts[3]])

        data.moveActiveChecks(in: id, fromOffsets: IndexSet(integer: 1), toOffset: 3)
        #expect(currentTexts(data) == texts)
    }

    @Test func movingKeepsWithdrawnChecksOutOfTheOrder() {
        var data = makeStandard()
        let id = data.currentAppointmentID
        data.updateCurrentAppointment { $0.checks[1].status = .withdrawn }
        let texts = PrototypeDataFactory.currentQuestionTexts

        data.moveActiveChecks(in: id, fromOffsets: IndexSet(integer: 0), toOffset: 3)

        #expect(currentTexts(data) == [texts[2], texts[3], texts[0]])
        #expect(data.currentChecks.last?.questionText == texts[1])
        #expect(data.currentChecks.count == 4)
    }

    // MARK: - 追加と割り当て

    @Test func addQuestionAppendsAnUnconfirmedCheck() {
        var data = makeStandard()

        data.addQuestion("新しい質問", to: data.currentAppointmentID)

        let last = data.currentChecks.last
        #expect(last?.questionText == "新しい質問")
        #expect(last?.status == .unconfirmed)
        #expect(data.questions.contains { $0.text == "新しい質問" })
    }

    @Test func assignKeepsTheGivenOrderAndEmptiesUnassigned() {
        var data = makeStandard()
        let unassignedIDs = data.unassignedQuestions.map(\.id)

        data.assign(questionIDs: unassignedIDs, to: data.currentAppointmentID)

        #expect(Array(currentTexts(data).suffix(2)) == PrototypeDataFactory.unassignedQuestionTexts)
        #expect(data.unassignedQuestions.isEmpty)
    }

    @Test func assignDoesNotDuplicateAQuestionAlreadyInTheAppointment() {
        var data = makeStandard()
        let existingID = data.currentChecks[0].questionID

        data.assign(questionIDs: [existingID], to: data.currentAppointmentID)

        #expect(data.currentChecks.count == 4)
    }

    @Test func assignRevivesAWithdrawnCheckInsteadOfAddingOne() {
        var data = makeStandard()
        data.updateCurrentAppointment { $0.checks[0].status = .withdrawn }
        let questionID = data.currentChecks[0].questionID

        data.assign(questionIDs: [questionID], to: data.currentAppointmentID)

        #expect(data.currentChecks.count == 4)
        #expect(data.currentChecks.filter { $0.questionID == questionID }.map(\.status) == [.unconfirmed])
    }

    // MARK: - 診察の開始

    @Test func startExamRecordsTheFirstTimeOnly() {
        var data = makeStandard()
        let id = data.currentAppointmentID
        let first = now
        let second = now.addingTimeInterval(600)

        data.startExam(of: id, at: first)
        data.startExam(of: id, at: second)

        #expect(data.currentAppointment.examStartedAt == first)
    }
}
